require 'shellwords'

module Cult
  module Drivers
    class VirtualBoxDriver < ::Cult::Driver
      def initialize(api_key:); end

      def sizes_map
        [1, 2, 4, 6, 8, 10, 12, 16].map do |size|
          ["#{size}gb", { ram: size * 1024, cores: size }]
        end.to_h
      end
      with_id_mapping :sizes_map

      def images_map
        vbox_manage('list', 'vms').each_line.map do |line|
          words = Shellwords.split(line.chomp)
          [distro_name(words[0]), words[1]]
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

      def vbox_manage(*args)
        cmd = ['VBoxManage', *(args.map { |a| Shellwords.escape(a.to_s) })]
        cmdline = cmd.join(" ")
        puts " > #{cmdline}"
        %x(#{cmdline})
      end

      def vbox_guest_control(name, *args)
        vbox_manage 'guestcontrol', name, *args
      end

      def unset_ip_data(name, index, protocol)
        vbox_manage 'guestproperty', 'unset', name, ip_property_name(index, protocol)
      end

      def get_ip_data(name, index, protocol)
        result = vbox_manage 'guestproperty', 'get', name, ip_property_name(index, protocol)
        if $?.success? && (m = result.match(/^Value: (.+)$/))
          m[1]
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
        vbox_manage 'controlvm', id, 'poweroff'
        vbox_manage 'unregistervm', id, '--delete'
      end

      def guest_copy(name, src, dst)
        # NOTE: Bug in current (Sep 2016) VBox has a fucked copyto, where setting target-directory
        # to the full path is a workaround
        vbox_guest_control \
          name,
          '--username', 'root',
          '--password', 'password',
          'copyto', src, '--target-directory', dst
      end

      def guest_command(name, cmd)
        vbox_guest_control \
          name,
          '--username', 'root',
          '--password', 'password',
          'run', '--', '/bin/sh', '-c', cmd
      end

      def provision!(name:, size:, zone:, image:, ssh_public_key:)
        transaction do |xac|
          vbox_manage \
            'clonevm',
            fetch_mapped(name: :image, from: images_map, key: image),
            '--groups', '/Cult',
            '--name', name,
            '--register'

          xac.rollback do
            destroy!(id: name, ssh_key_id: nil)
          end

          system_spec = sizes_map[size]

          vbox_manage \
            'modifyvm', name,
            '--memory', system_spec[:ram].to_s,
            '--cpus', system_spec[:cores].to_s

          vbox_manage 'startvm', name, '--type', 'headless'

          public_ip  = await_ip_address(name, 0, :ipv4)
          private_ip = public_ip

          await_ssh(public_ip)

          guest_command(name, "mkdir -m 0600 /root/.ssh")
          guest_copy(name, ssh_public_key, "/root/.ssh/authorized_keys")
          guest_command(name, "chmod 0644 /root/.ssh/authorized_keys")
          guest_command(name, "passwd -l root")

          return {
            name: name,
            size: size,
            zone: zone,
            image: image,

            id: name,
            created_at: Time.now.iso8601,
            host: public_ip,
            ipv4_public: public_ip,
            ipv4_private: private_ip,
            ipv6_public: nil,
            ipv6_private: nil,
            meta: {}
          }
        end
      end

      def self.setup!
        super

        inst = new(api_key: nil)

        {
          driver: driver_name,
          api_key: nil,
          configurations: {
            sizes: inst.sizes,
            zones: inst.zones,
            images: inst.images,
          }
        }
      end
    end
  end
end
