require 'cult/vps/provider'

module Cult
  module VPS

    class DigitalOceanProvider < Provider
      self.required_gems = 'droplet_kit'

      include SSHSpin
      attr_reader :conf
      attr_reader :client

      def initialize(conf = {})
        @conf = conf
        @client = DropletKit::Client.new(access_token: conf['access-token'])
      end

      def await_creation(droplet)
        loop do
          begin
            d = client.droplets.find(id: droplet.id)
            return d if d.status == 'active'
          rescue DropletKit::Error
          end
          sleep 3
        end
      end


      def provision(name:, spec_name:)
        spec = @conf['machine-specs'][spec_name]
        if spec.nil?
          fail ArgumentError, "Unknown spec_name: #{spec_name}"
        end

        params = spec.map {|k,v| [k.to_sym, v]}.to_h
        params[:name] = name

        droplet = DropletKit::Droplet.new(params)
        droplet = client.droplets.create(droplet)
        droplet = await_creation(droplet)

        ipv4_public  = droplet.networks.v4.find {|n| n.type == 'public' }
        ipv4_private = droplet.networks.v4.find {|n| n.type == 'private' }
        ipv6_public  = droplet.networks.v6.find {|n| n.type == 'public' }
        ipv6_private = droplet.networks.v6.find {|n| n.type == 'private' }

        ssh_spin(ipv4_public.ip_address)

        {
          id:           droplet.id,
          name:         droplet.name,
          created_at:   droplet.created_at,
          ipv4_public:  ipv4_public&.ip_address,
          ipv4_private: ipv4_private&.ip_address,
          ipv6_public:  ipv6_public&.ip_address,
          ipv6_private: ipv6_private&.ip_address,
        }
      end

      def launch_browser(url)
        case RUBY_PLATFORM
          when /darwin/
            system "open", url
          when /mswin|mingw|cygwin/
            system "start", url
          else
            system "xdg-open", url
        end
      end

      def setup!
        url = "https://cloud.digitalocean.com/settings/api/tokens/new"

        puts "Cult needs a read/write Access Token created for your " +
             "DigitalOcean account."
        puts "One can be generated at the following URL:"
        puts
        puts "  #{url}"
        puts
        print "Open browser? [Y/n]: "

        launch_browser(url) unless $stdin.gets.match(/^[Nn]/)

        print "Access Token: "
        access_token = $stdin.gets.chomp
        unless access_token.match(/\A[0-9a-f]{64}\z/)
          puts "That doesn't look like an access token, but we'll take it."
        end

        return {
          'access-token' => access_token,
          'machine-specs' => {
            'small' => {
              'size'  => '512mb',
              'image' => 'ubuntu-16-04-x64',
              'region' => 'nyc1',
              'ipv6'   => true,
              'private_networking' => true
            }
          }
        }
      end
    end

  end
end
