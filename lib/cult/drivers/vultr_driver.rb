require 'cult/driver'
require 'cult/drivers/common'

require 'net/ssh'
require 'time'

module Cult
  module Drivers
    class VultrDriver < ::Cult::Driver
      self.required_gems = 'vultr'

      include Common

      attr_reader :api_key

      def initialize(api_key:)
        @api_key = api_key
      end


      # This sets the Vultr API key to this instance's api key for the duration
      # of a method call and restores it afterwards.
      def self.with_api_key(method_name)
        unwrapped_name = "#{method_name}_no_api_key".to_sym
        alias_method unwrapped_name, method_name
        define_method(method_name) do |*args, &block|
          old_api_key = Vultr.api_key
          begin
            Vultr.api_key = self.api_key
            return send(unwrapped_name, *args, &block)
          ensure
            Vultr.api_key = old_api_key
          end
        end
      end


      def zones_map
        Vultr::Region.list[:result].map do |k, v|
          [slugify(v["regioncode"]), v["DCID"]]
        end.to_h
      end
      memoize         :zones_map
      with_id_mapping :zones_map
      with_api_key    :zones_map


      def images_map
        Vultr::OS.list[:result].select do |k, v|
          # Doing our part to kill x86/32
          v['arch'] == 'x64'
        end.map do |k,v|
          [slugify(distro_name(v["name"])), v["OSID"]]
        end.reject do |k,v|
          %w(custom snapshot backup application).include?(k) ||
          k.match(/^windows/)
        end.to_h
      end
      memoize         :images_map
      with_id_mapping :images_map
      with_api_key    :images_map


      def sizes_map
        Vultr::Plan.list[:result].values.select do |v|
          v["plan_type"] == 'SSD'
        end.map do |v|
          if (m = v["name"].match(/^(\d+) ([MGTP]B) RAM/i))
            _, ram, unit = *m
            ram = ram.to_i

            if unit == "MB" && ram >= 1024
              ram = ram / 1024
              unit = "GB"
            end

            if unit == "GB" && ram >= 1024
              ram = ram / 1024
              unit = "TB"
            end

            ["#{ram}#{unit}".downcase, v["VPSPLANID"] ]
          else
            nil
          end
        end.compact.to_h
      end
      memoize         :sizes_map
      with_id_mapping :sizes_map
      with_api_key    :sizes_map


      def ssh_keys
        Vultr::SSHKey.list[:result].values
      end
      memoize      :ssh_keys
      with_api_key :ssh_keys


      def upload_ssh_key(file:)
        key = ssh_key_info(file: file)

        vkey = if (exist = ssh_keys.find {|e| e["ssh_key"] == key[:data] })
          exist
        else
          ssh_keys_dememo!
          Vultr::SSHKey.create(name: "Cult: #{key[:name]}",
                               ssh_key: key[:data])[:result]
        end

        vkey["fingerprint"] = key[:fingerprint]
        vkey
      end
      with_api_key :upload_ssh_key


      def fetch_ip(list, type)
        goal = (type == :public ? "main_ip" : "private")
        r = list.find{ |v| v["type"] == goal }
        r.nil? ? nil : r["ip"]
      end


      def destroy!(id:)
        Vultr::Server.destroy(SUBID: id)
      end
      with_api_key :destroy!


      def provision!(name:, size:, zone:, image:, ssh_key_files:, extra: {})
        keys = Array(ssh_key_files).map do |filename|
          upload_ssh_key(file: filename)
        end

        sizeid  = fetch_mapped(name: :size, from: sizes_map, key: size)
        imageid = fetch_mapped(name: :image, from: images_map, key: image)
        zoneid  = fetch_mapped(name: :zone, from: zones_map, key: zone)

        r = Vultr::Server.create(DCID: zoneid,
                                 OSID: imageid,
                                 VPSPLANID: sizeid,
                                 enable_ipv6: 'yes',
                                 enable_private_network: 'yes',
                                 label: name,
                                 hostname: name,
                                 SSHKEYID: keys.map{|v| v["SSHKEYID"] }
                                               .join(','))

        subid = r[:result]["SUBID"]

        rollback_on_error(id: subid) do
          # Wait until it's active, it won't have an IP until then
          backoff_loop do
            r = Vultr::Server.list(SUBID: subid)[:result]
            throw :done if r['status'] == 'active'
          end

          iplist4 = Vultr::Server.list_ipv4(SUBID: subid)[:result].values[0]
          iplist6 = Vultr::Server.list_ipv6(SUBID: subid)[:result].values[0]

          host = fetch_ip(iplist4, :public)
          await_ssh(host)

          return {
              name:          name,
              size:          size,
              zone:          zone,
              image:         image,
              ssh_key_files: ssh_key_files,
              ssh_keys:      keys.map{|v| v["fingerprint"]},
              extra:         extra,

              id:           subid,
              created_at:   Time.now.iso8601,
              host:         host,
              ipv4_public:  host,
              ipv4_private: fetch_ip(iplist4, :private),
              ipv6_public:  fetch_ip(iplist6, :public),
              ipv6_private: fetch_ip(iplist6, :private),
              meta:         {}
          }
        end
      end
      with_api_key :provision!


      def self.setup!
        super
        url = "https://my.vultr.com/settings/#settingsapi"
        puts "Vultr does not generate multiple API keys, so you'll need to "
             "create one (if it does not exist).  You can access your API key "
             "at the following URL:"
        puts
        puts "  #{url}"
        puts

        CLI.launch_browser(url) if CLI.yes_no?("Launch browser?")

        api_key = CLI.prompt("API Key")

        unless api_key.match(/^[A-Z2-7]{36}$/)
          puts "That doesn't look like an API key, but I'll trust you"
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
