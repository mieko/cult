require 'cult/driver'
require 'cult/drivers/common'
require 'net/ssh'

module Cult
  module Drivers

    class DigitalOceanDriver < ::Cult::Driver
      self.required_gems = 'droplet_kit'

      include Common

      attr_reader :access_token
      attr_reader :client

      def initialize(api_key:)
        @access_token = api_key
        @client = DropletKit::Client.new(access_token: access_token)
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
          @ssh_keys = nil
        end

        do_key
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
        backoff_loop do
          d = client.droplets.find(id: droplet.id)
          throw :done if d.status == 'active'
        end
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
          ssh_keys: fingerprints,

          private_networking: true,
          ipv6: true
        }

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

        CLI.launch_browser(url) if CLI.yes_no("Open Browser?")

        api_key = CLI.prompt("Access Token")
        unless api_key.match(/\A[0-9a-f]{64}\z/)
          puts "That doesn't look like an access token, but we'll take it."
        end

        inst = new(api_key: api_key)

        return {
          api_key: api_key,
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
