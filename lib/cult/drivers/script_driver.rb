require 'cult/driver'

module Cult
  module Drivers

    class ScriptDriver < ::Cult::Driver
      include Common
      
      def initialize(*args)
        raise NotImplementedError
      end

      def self.setup!
        super
      end
    end

  end
end
