require 'cult/driver'
require 'cult/cli/common'

module Cult
  module LinodeMonkeyPatch

    def fetch_api_key(label: nil, expire_hours: :default)
      request = {
        api_action: 'user.getapikey',
        api_responseFormat: 'json',
        username: self.username,
        password: self.password
      }

      request[:label] = label if label

      if expire_hours != :default
        request[:expires] = expire_hours.nil? ? 0 : expire_hours
      end

      response = post(request)
      if error?(response)
        fail "Errors completing request [user.getapikey] @ [#{api_url}] for " +
             "username [#{username}]:\n" +
             "#{error_message(response, 'user.getapikey')}"
      end
      reformat_response(response).api_key
    end

    module_function
    def install!
      ::Linode.prepend(::Cult::LinodeMonkeyPatch)
    end
  end
end

module Cult
  module Drivers
    class LinodeDriver < ::Cult::Driver
      include Common

      self.required_gems = 'linode'

      attr_reader :client

      def slug(s)
        s.downcase.gsub(/[^a-z0-9]/, '-')
      end

      def initialize(api_key:)
        LinodeMonkeyPatch.install!
        @client = Linode.new(api_key: api_key)
      end

      def images
        client.avail.distributions.select(&:is64bit).map do |v|
          name = v.label
          { slug(v.label) => v.distributionid }
        end
      end

      def zones
        client.avail.datacenters.map do |v|
          { slug(v.abbr) => v.datacenterid }
        end
      end

      def sizes
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
          { slug(name) => v.planid }
        end
      end

      def provision!(name:, size:, zone:, ssh_key_files:)
        sizeid = sizes.find {|k, v| k == name }[1]
        zoneid = zones.find {|k, v| k == zone}[1]
        result = client.linode.create(datacenterid: zoneid, planid: sizeid)
        linodeid = result.linodeid

        client.linode.update(linodeid: linodeid, label: name,)
        client.linode.ip.addprivate(linodeid: linodeid)
      end

      def self.interrupts
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
              linode.send(:fetch_api_key, label: "Cult", expire_hours: nil)
              api_key = linode.api_key
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
          if CLI.yes_no("Open Browser?")
            CLI.launch_browser(url)
            api_key = CLI.ask("API Key")
          end
        end
        linode ||= Linode.new(api_key: api_key)
        resp = linode.test.echo(message: "PING")
        if resp.message != 'PING'
        end
      end

    end
  end
end
