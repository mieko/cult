require 'cult/vps/provider'

module Cult
  module VPS

    class DigitalOcean < Provider
      self.required_gems = 'droplet_kit'

      attr_reader :client

      def initialize(config = {})
        @client = DropletKit::Client.new(access_token: config['access-token'])
      end

      def provision(role)
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
          'access-token' => access_token
        }
      end
    end

  end
end
