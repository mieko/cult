require 'cult/vps/provider'

module Cult
  module VPS

    class DigitalOcean < Provider
      self.required_gems = 'droplet_kit'

      def initialize(configuration)
        @conf = configuration
      end
    end

  end
end
