require 'cult/driver'
require 'cult/drivers/common'
require 'net/ssh'

module Cult
  module Drivers

    class DigitalOceanDriver < ::Cult::Driver
      include Common

      self.required_gems = 'droplet_kit'

      attr_accessor :access_token
      def initialize(api_key:)
        @access_token = api_key
      end

      def client
        @client ||= DropletKit::Client.new(access_token: access_token)
      end

      def sizes
        @sizes ||= begin
          client.sizes.all.to_a.map(&:slug)
        end
      end

      def ssh_keys
        @ssh_keys ||= begin
          client.ssh_keys.all.to_a.map(&:to_h)
        end
      end

      def upload_ssh_key(file:)
        data = File.read(file).chomp
        fields = data.split(/ /)
        name = fields[-1]

        key = Net::SSH::KeyFactory.load_data_public_key(data, file)
        do_key = DropletKit::SSHKey.new(fingerprint: key.fingerprint,
                                        public_key: data,
                                        name: name)
        unless ssh_keys.find {|e| e[:fingerprint] == do_key.fingerprint }
          do_key = client.ssh_keys.create(do_key)
        end

        @ssh_keys = nil
        do_key
      end

      def size_norm(size_string)
        units = {
          mb: 1024 ** 1,
          gb: 1024 ** 2,
          tb: 1024 ** 3,
          pb: 1024 ** 4,
        }
        _, v, unit = *(size_string.match(/^(\d+)([mgtp]b)/i))
        v.to_i * units[unit.to_sym]
      end

      def distro_score(s)
        distro_score = case s
          when /^ubuntu/; 2
          when /^debian/; 1
          else ; 0
        end
        rest = s.gsub(/^[^-]*\-/, '')
        [distro_score, rest]
      end

      def images
        @images ||= begin
          distros = %w(ubuntu coreos centos freebsd fedora debian).join '|'
          re = /^(#{distros})\-.*\-x64$/
          client.images.all.to_a.select do |image|
            image.public && image.slug && image.slug.match(re)
          end.map(&:slug)
        end
      end

      def zones
        @zones ||= begin
          client.regions.all.map(&:slug)
        end
      end

      def await_creation(droplet)
        wait = 3
        mul = 1.2
        loop do
          begin
            d = client.droplets.find(id: droplet.id)
            return d if d.status == 'active'
          rescue DropletKit::Error
          end
          sleep wait
          wait *= mul
        end
      end

      def provision_defaults
        {
          private_networking: true,
          ipv6: true
        }
      end


      def provision!(name:, size:, image:, zone:, ssh_key_files:, extra: {})
        fingerprints = Array(ssh_key_files).map do |file|
          upload_ssh_key(file: file).fingerprint
        end

        params = {
          name:     name,
          region:   zone,
          image:    image,
          size:     size,
          ssh_keys: fingerprints
        }

        params = provision_defaults.merge(extra).merge(params)

        droplet = DropletKit::Droplet.new(params)
        droplet = client.droplets.create(droplet)
        droplet = await_creation(droplet)

        ipv4_public  = droplet.networks.v4.find {|n| n.type == 'public'  }
        ipv4_private = droplet.networks.v4.find {|n| n.type == 'private' }
        ipv6_public  = droplet.networks.v6.find {|n| n.type == 'public'  }
        ipv6_private = droplet.networks.v6.find {|n| n.type == 'private' }

        ssh_spin(ipv4_public.ip_address)
        return {
            name:          droplet.name,
            size:          size,
            zone:          zone,
            image:         image,
            ssh_key_files: ssh_key_files,
            ssh_keys:      fingerprints,
            extra:         extra,

            id:           droplet.id,
            created_at:   droplet.created_at,
            host:         ipv4_public&.ip_address,
            ipv4_public:  ipv4_public&.ip_address,
            ipv4_private: ipv4_private&.ip_address,
            ipv6_public:  ipv6_public&.ip_address,
            ipv6_private: ipv6_private&.ip_address,
            meta:         JSON.parse(droplet.to_json)
        }
      end

      def self.setup!
        super
        url = "https://cloud.digitalocean.com/settings/api/tokens/new"

        puts "Cult needs a read/write Access Token created for your " +
             "DigitalOcean account."
        puts "One can be generated at the following URL:"
        puts
        puts "  #{url}"
        puts
        print "Open browser? [Y/n]: "

        Common.launch_browser(url) unless $stdin.gets.match(/^[Nn]/)

        print "Access Token: "
        access_token = $stdin.gets.chomp
        unless access_token.match(/\A[0-9a-f]{64}\z/)
          puts "That doesn't look like an access token, but we'll take it."
        end

        inst = new(access_token: access_token)

        return {
          access_token: access_token,
          configurations: {
            sizes:  inst.sizes,
            zones:  inst.zones,
            images: inst.images,
          },
          default_node: {
            size:  inst.sizes.sort_by(&inst.method(:size_norm))[0],
            zone:  inst.zones.sample,
            image: inst.images.sort_by(&inst.method(:distro_score)).last
          }
        }
      end
    end

  end
end
