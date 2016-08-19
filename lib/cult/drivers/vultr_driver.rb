require 'cult/driver'
require 'cult/drivers/common'

require 'net/ssh'
require 'time'

module Cult
  module Drivers
    class VultrDriver < ::Cult::Driver
      include Common
      self.required_gems = 'vultr'

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

      # Lets us write a method "something_map" that returns
      # {'ident' => ... id}, and also get a function "something" that
      # returns the keys.
      def self.with_id_mapping(method_name)
        new_method = method_name.to_s.sub(/_map\z/, '')
        define_method(new_method) do
          send(method_name).keys
        end
      end

      def slugify(s)
        s.gsub(/[^a-z0-9]+/i, '-').gsub(/(^\-)|(-\z)/, '').downcase
      end

      def zones_map
        Vultr::Region.list[:result].map do |k, v|
          [slugify(v["regioncode"]), v["DCID"]]
        end.to_h
      end
      with_id_mapping :zones_map
      with_api_key :zones_map

      def images_map
        Vultr::OS.list[:result].select do |k, v|
          # Doing our part to kill x86/32
          v['arch'] == 'x64'
        end.map do |k,v|
          [slugify(v["name"]), v["OSID"]]
        end.reject do |k,v|
          %w(custom snapshot backup application).include?(k) ||
          k.match(/^windows/)
        end.to_h
      end
      with_id_mapping :images_map
      with_api_key :images_map

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
      with_id_mapping :sizes_map
      with_api_key :sizes_map

      def ssh_keys
        Vultr::SSHKey.list[:result].values
      end
      with_api_key :ssh_keys

      def upload_ssh_key(file:)
        data = File.read(file).chomp

        fields = data.split(/ /)
        name = fields[-1]

        key = Net::SSH::KeyFactory.load_data_public_key(data, file)
        existing = ssh_keys.find {|e| e["ssh_key"] == data }
        if existing.nil?
          existing = Vultr::SSHKey.create(name: "Cult: #{name}",
                                          ssh_key: data)[:result]
        end
        existing["fingerprint"] = key.fingerprint
        existing
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

        r = Vultr::Server.create(DCID: zones_map.fetch(zone),
                                 VPSPLANID: sizes_map.fetch(size),
                                 OSID: images_map.fetch(image),
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

        CLI.launch_browser(url) if CLI.yes_no("Launch browser?")

        api_key = CLI.prompt("API Key")
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
