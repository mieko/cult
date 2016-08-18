require 'cult/driver'
require 'cult/drivers/common'

module Cult
  module Drivers

    class ScriptDriver < ::Cult::Driver
      include Common

      def initialize(api_key:)
        fail NotImplementedError
      end

      def provision!(name:, size:, zone:, image:, ssh_key_files:, extra: {})
        fail NotImplementedError
      end

      def self.setup!
        super
        fail NotImplementedError
      end
    end

  end
end
