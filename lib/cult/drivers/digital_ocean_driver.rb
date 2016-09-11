require 'json'

module Cult
  module Drivers

    class DigitalOceanDriver < ::Cult::Driver
      self.required_gems = 'droplet_kit'

      attr_reader :client

      def initialize(api_key:)
        @client = DropletKit::Client.new(access_token: api_key)
      end


      def sizes_map
        client.sizes.all.to_a.map do |s|
          [s.slug, s.slug]
        end.to_h
      end
      memoize :sizes_map
      with_id_mapping :sizes_map


      def images_map
        distros = %w(ubuntu coreos centos freebsd fedora debian).join '|'
        re = /^(#{distros})\-.*\-x64$/
        client.images.all.to_a.select do |image|
          image.public && image.slug && image.slug.match(re)
        end.map do |image|
          [slugify(distro_name(image.slug)), image.slug]
        end.to_h
      end
      memoize :images_map
      with_id_mapping :images_map


      def zones_map
        client.regions.all.map do |zone|
          [zone.slug, zone.slug]
        end.to_h
      end
      memoize :zones_map
      with_id_mapping :zones_map



      def upload_ssh_key(file:)
        key = ssh_key_info(file: file)
        # If we already have one with this fingerprint, use it.
        dk_key = DropletKit::SSHKey.new(public_key: key[:data],
                                        name: "Cult: #{key[:name]}")
        client.ssh_keys.create(dk_key).id
      end


      def await_creation(droplet)
        d = nil
        backoff_loop do
          d = client.droplets.find(id: droplet.id)
          throw :done if d.status == 'active'
        end
        return d
      end


      def destroy!(id:, ssh_key_id: nil)
        client.droplets.delete(id: id)
        destroy_ssh_key!(ssh_key_id: ssh_key_id) if ssh_key_id
      end

      def destroy_ssh_key!(ssh_key_id:)
        client.ssh_keys.delete(id: ssh_key_id)
      end

      def provision!(name:, size:, zone:, image:, ssh_public_key:)
        transaction do |xac|
          ssh_key_id = upload_ssh_key(file: ssh_public_key)
          xac.rollback do
            destroy_ssh_key!(id: ssh_key_id)
          end

          begin
            params = {
              name:     name,
              size:     fetch_mapped(name: :size, from: sizes_map, key: size),
              image:    fetch_mapped(name: :image, from: images_map, key: image),
              region:   fetch_mapped(name: :zone, from: zones_map, key: zone),
              ssh_keys: [ssh_key_id],

              private_networking: true,
              ipv6: true
            }
          rescue KeyError => e
            fail ArgumentError, "Invalid argument: #{e.message}"
          end

          droplet = DropletKit::Droplet.new(params)

          if droplet.nil?
            fail "Droplet was nil: #{params.inspect}"
          end

          droplet = client.droplets.create(droplet)
          xac.rollback do
            destroy!(id: droplet.id)
          end

          droplet = await_creation(droplet)

          ipv4_public  = droplet.networks.v4.find {|n| n.type == 'public'  }
          ipv4_private = droplet.networks.v4.find {|n| n.type == 'private' }
          ipv6_public  = droplet.networks.v6.find {|n| n.type == 'public'  }
          ipv6_private = droplet.networks.v6.find {|n| n.type == 'private' }

          await_ssh(ipv4_public.ip_address)
          return {
              name:          droplet.name,
              size:          size,
              zone:          zone,
              image:         image,

              ssh_key_id:    ssh_key_id,

              id:            droplet.id,
              created_at:    droplet.created_at,
              host:          ipv4_public&.ip_address,
              ipv4_public:   ipv4_public&.ip_address,
              ipv4_private:  ipv4_private&.ip_address,
              ipv6_public:   ipv6_public&.ip_address,
              ipv6_private:  ipv6_private&.ip_address,
              # Get rid of magic in droplet.
              meta:          JSON.parse(droplet.to_json)
          }
        end
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

        CLI.launch_browser(url) if CLI.yes_no?("Open Browser?")

        api_key = CLI.prompt("Access Token")
        unless api_key.match(/\A[0-9a-f]{64}\z/)
          puts "That doesn't look like an access token, but we'll take it."
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
