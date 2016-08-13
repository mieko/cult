require 'cult/vps/provider'

module Cult
  module VPS
    class LinodeProvider < Provider
      self.required_gems = 'linode'

      attr_reader :conf
      attr_reader :client

      def initialize(conf = {})
        @conf = conf
        @client = Linode.new(api_key: conf['api-key'])
      end

    end
  end
end
