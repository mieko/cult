require 'cult/driver'

module Cult
  module Drivers
    class VultrDriver < ::Cult::Driver
      include Common
      self.required_gems = 'vultr'

      attr_reader :conf
      attr_reader :client

      def initialize(api_key:)
        fail NotImplementedError

        @client = nil
      end

      def self.setup!
        super
      end
    end
  end
end
