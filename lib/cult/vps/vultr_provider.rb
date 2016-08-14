require 'cult/vps/provider'

module Cult
  module VPS
    class VultrProvider < Provider
      self.required_gems = 'vultr'

      attr_reader :conf
      attr_reader :client

      def initialize(conf = {})
        fail NotImplementedError
        
        @conf = conf
        @client = nil
      end

    end
  end
end
