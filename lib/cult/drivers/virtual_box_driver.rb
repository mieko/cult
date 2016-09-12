require 'shellwords'

module Cult
  module Drivers
    class VirtualBoxDriver < ::Cult::Driver

      def initialize(api_key:)
      end


      def sizes_map
        [1, 2, 4, 6, 8, 10, 12, 16].map do |size|
          ["#{size}gb", size * 1024 * 1024]
        end.to_h
      end
      with_id_mapping :sizes_map


      def images_map
        %x(VBoxManage list vms).each_line.map do |line|
          words = Shellwords.split(line.chomp)
          [ distro_name(words[0]), words[1] ]
        end.to_h
      end
      with_id_mapping :images_map


      def zones
        ['local']
      end


      def ip_property_name(index, protocol)
        protocols = {
          ipv4: 'V4',
          ipv6: 'V6'
        }
        "/VirtualBox/GuestInfo/Net/#{index}/#{protocols[protocol]}/IP"
      end


      def esc(s)
        Shellwords.escape(s)
      end


      def unset_ip_data(name, index, protocol)
        cmd = "VBoxManage guestproperty unset #{esc(name)} " +
              "#{ip_property_name(index, protocol)}"
        `#{cmd}`
      end


      def get_ip_data(name, index, protocol)
        cmd = "VBoxManage guestproperty get #{esc(name)} " +
              "#{ip_property_name(index, protocol)}"
        s = `#{cmd}`

        if $?.success? && (m = s.match(/^Value: (.+)$/))
          m[1]
        else
          nil
        end
      end


      def await_ip_address(name, index, protocol)
        puts "Awaiting IP address from VirtualBox Guest Additions"
        unset_ip_data(name, index, protocol)

        backoff_loop do
          if (ip = get_ip_data(name, index, protocol))
            return ip
          end
        end
      end


      def destroy!(id:, ssh_key_id:)
        system 'VBoxManage', 'controlvm', id, 'poweroff'
        system 'VBoxManage', 'unregistervm', id, '--delete'
      end


      def guest_copy(name, src, dst)
        cmd = "VBoxManage guestcontrol #{esc(name)} " +
              "--username root --password password " +
              "copyto #{esc(src)} --target-directory #{esc(dst)}"
        puts cmd
        `#{cmd}`
      end


      def guest_command(name, cmd)
        cmd = "VBoxManage guestcontrol #{esc(name)} " +
              "--username root --password password " +
              "run -- /bin/sh -c #{esc(cmd)}"
        puts cmd
        `#{cmd}`
      end


      def provision!(name:, size:, zone:, image:, ssh_public_key:)
        system 'VBoxManage', 'clonevm',
                fetch_mapped(name: :image, from: images_map, key: image),
               '--name', name, '--register'

        system 'VBoxManage', 'modifyvm', name, '--groups', '/Cult'
        system 'VBoxManage', 'startvm', name, '--type', 'headless'

        public_ip  = await_ip_address(name, 0, :ipv4)
        private_ip = public_ip

        await_ssh(public_ip)

        guest_command(name, "mkdir -m 0600 /root/.ssh")
        guest_copy(name, ssh_public_key, "/root/.ssh/authorized_keys")
        guest_command(name, "chmod 0644 /root/.ssh/authorized_keys")
        guest_command(name, "passwd -l root")

        return {
            name:          name,
            size:          size,
            zone:          zone,
            image:         image,

            id:           name,
            created_at:   Time.now.iso8601,
            host:         public_ip,
            ipv4_public:  public_ip,
            ipv4_private: private_ip,
            ipv6_public:  nil,
            ipv6_private: nil,
            meta:         {}
        }
      end

      def self.setup!
        super

        inst = new(api_key: nil)

        return {
          driver: driver_name,
          api_key: nil,
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
