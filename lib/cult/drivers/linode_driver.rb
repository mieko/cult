require 'cult/driver'
require 'cult/cli/common'

require 'securerandom'
require 'time'

module Cult
  # This has been submitted as a PR.  It lets us set a label and custom
  # expiration length for an API key.
  #  See: https://github.com/rick/linode/pull/34
  module LinodeMonkeyPatch
    def fetch_api_key(options = {})
      request = {
        api_action: 'user.getapikey',
        api_responseFormat: 'json',
        username: username,
        password: password
      }

      if options.key?(:label)
        request[:label] = options[:label]
      end

      if options.key?(:expires)
        expires = options[:expires]
        request[:expires] = expires.nil? ? 0 : expires
      end

      response = post(request)
      if error?(response)
        fail "Errors completing request [user.getapikey] @ [#{api_url}] for " +
             "username [#{username}]:\n" +
             "#{error_message(response, 'user.getapikey')}"
      end
      reformat_response(response).api_key
    end
    public :fetch_api_key

    module_function
    def install!
      ::Linode.prepend(self)
    end
  end
end

module Cult
  module Drivers
    class LinodeDriver < ::Cult::Driver
      self.required_gems = 'linode'

      include Common

      SWAP_SIZE = 256

      attr_reader :client

      def initialize(api_key:)
        LinodeMonkeyPatch.install!
        @client = Linode.new(api_key: api_key)
      end


      def images_map
        client.avail.distributions.select(&:is64bit).map do |v|
          name = v.label
          [ slugify(distro_name(v.label)), v.distributionid ]
        end.to_h
      end
      memoize         :images_map
      with_id_mapping :images_map


      def zones_map
        client.avail.datacenters.map do |v|
          [ slugify(v.abbr), v.datacenterid ]
        end.to_h
      end
      memoize         :zones_map
      with_id_mapping :zones_map


      def sizes_map
        client.avail.linodeplans.map do |v|
          name = v.label.gsub(/^Linode /, '')
          if name.match(/^\d+$/)
            mb = name.to_i
            if mb < 1024
              "#{mb}mb"
            else
              name = "#{mb / 1024}gb"
            end
          end
          [ slugify(name), v.planid ]
        end.to_h
      end
      memoize         :sizes_map
      with_id_mapping :sizes_map


      # We try to use the reasonable sizes that the web UI uses, although the
      # API lets us change it.
      def disk_size_for_size(size)
        gb = 1024
        {
          '2gb'    => 24   * gb,
          '4gb'    => 48   * gb,
          '8gb'    => 96   * gb,
          '12gb'   => 192  * gb,
          '24gb'   => 384  * gb,
          '48gb'   => 768  * gb,
          '64gb'   => 1152 * gb,
          '80gb'   => 1536 * gb,
          '120gb'  => 1920 * gb
        }.fetch(size.to_s)
      end


      # I've been told by Linode support that this literal will always mean
      # "Latest x86".  But in case that changes...
      def latest_kernel_id
        @latest_kernel_id ||= 138 || begin
          client.avail.kernels.find {|k| k.label.match(/^latest 64 bit/i)}
        end.kernelid
      end


      def destroy!(id:)
        client.linode.delete(linodeid: id, skipchecks: true)
      end


      def provision!(name:, size:, zone:, image:, ssh_key_files:, extra: {})
        begin
          sizeid   = sizes_map.fetch size.to_s
          zoneid   = zones_map.fetch zone.to_s
          imageid  = images_map.fetch image.to_s
          disksize = disk_size_for_size(size)
        rescue KeyError
          msg = "Tried to create an instance with an unknown value: " +
                "size #{size}(aka #{sizeid}), " +
                "zone #{zone}(aka #{zoneid}), " +
                "image #{image}(aka #{imageid}), " +
                "disksize #{disksize}"
          fail ArgumentError, msg
        end
        linodeid = client.linode.create(datacenterid: zoneid,
                                        planid: sizeid).linodeid

        rollback_on_error(id: linodeid) do
          # We give it a name early so we can find it in the Web UI if anything
          # goes wrong.
          client.linode.update(linodeid: linodeid, label: name)
          client.linode.ip.addprivate(linodeid: linodeid)

          ssh_keys = Array(ssh_key_files).map do |file|
            ssh_key_info(file: file)
          end

          # You shouldn't run meaningful swap, but this makes the Web UI not
          # scare you, and apparently Linux runs better with ANY swap,
          # regardless of how small.  We've matched the small size the Linode
          # Web UI does by default.
          swapid = client.linode.disk.create(linodeid: linodeid,
                                             label: "Cult: #{name}-swap",
                                             type: "swap",
                                             size: SWAP_SIZE).diskid

          # Here, we create the OS on-node storage
          params = {
            linodeid: linodeid,
            distributionid: imageid,
            label: "Cult: #{name}",
            # Linode's max length is 128, generates longer than that to
            # no get the fixed == and truncates.
            rootpass: SecureRandom.base64(100)[0...128],
            rootsshkey: ssh_keys.map {|k| k[:data] }.join("\n"),
            size: disksize - SWAP_SIZE
          }

          diskid = client.linode.disk.createfromdistribution(params).diskid


          # We don't have to reference the config specifically: It'll be the only
          # configuration that exists, so it'll be used.
          client.linode.config.create(linodeid: linodeid,
                                      kernelid: latest_kernel_id,
                                      disklist: "#{diskid},#{swapid}",
                                      rootdevicenum: 1,
                                      label: "Cult: Latest Linux-x64")

          client.linode.reboot(linodeid: linodeid)

          # Information gathering step...
          all_ips = client.linode.ip.list(linodeid: linodeid)

          ipv4_public  = all_ips.find{ |ip| ip.ispublic == 1 }&.ipaddress
          ipv4_private = all_ips.find{ |ip| ip.ispublic == 0 }&.ipaddress

          # This is a shame: Linode has awesome support for ipv6, but doesn't
          # expose it in the API.
          ipv6_public  = nil
          ipv6_private = nil

          await_ssh(ipv4_public)

          return {
              name:          name,
              size:          size,
              zone:          zone,
              image:         image,
              ssh_key_files: ssh_keys.map{|k| k[:file]},
              ssh_keys:      ssh_keys.map{|k| k[:fingerprint]},
              extra:         extra,

              id:           linodeid,
              created_at:   Time.now.iso8601,
              host:         ipv4_public,
              ipv4_public:  ipv4_public,
              ipv4_private: ipv4_private,
              ipv6_public:  ipv6_public,
              ipv6_private: ipv6_private,
              meta:         {}
          }
        end
      end


      def self.interrupts
        # I hate IRB.
        [Interrupt] + (defined?(IRB) ? [IRB::Abort] : [])
      end


      def self.setup!
        super
        LinodeMonkeyPatch.install!

        linode = nil
        api_key = nil

        begin
          loop do
            puts "Cult needs an API key.  It can get one for you, but will " +
                 "need your Linode username and password.  If you'd rather "
                 "generate it at Linode, hit ctrl-c"
            username = CLI.ask "Username"
            password = CLI.password "Password"
            linode = Linode.new(username: username, password: password)
            begin
              linode.fetch_api_key(label: "Cult", expires: nil)
              api_key = linode.api_key
              fail RuntimeError if api_key.nil?
              puts "Got it!  In case you're curious: #{api_key}"
            rescue RuntimeError
              puts "Linode disagreed with your password."
              next if CLI.yes_no("Try again?")
            end
            break
          end
        rescue *interrupts
          puts
          url = "https://manager.linode.com/profile/api"
          puts "You can obtain an API key for Cult at the following URL:"
          puts "  #{url}"
          puts
          CLI.launch_browser(url) if CLI.yes_no("Open Browser?")
          api_key = CLI.prompt("API Key")
        end

        linode ||= Linode.new(api_key: api_key)
        resp = linode.test.echo(message: "PING")
        if resp.message != 'PING'
          raise "Didn't respond to ping.  Something went wrong."
        end

        inst = new(api_key: api_key)

        return {
          api_key: api_key,
          driver: driver_name,
          configurations: {
            sizes:  inst.sizes,
            zones:  inst.zones,
            images: inst.images,
          }
        }
      end

    end
  end
end
