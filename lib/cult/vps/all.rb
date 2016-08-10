require 'cult/vps/provider'

module Cult
  module VPS

    module_function
    def load_providers!
      Dir.glob(File.join(__dir__, "*_provider.rb")).each do |file|
        require file
      end
    end

    def providers
      Cult::VPS.constants(false).map do |m|
        Cult::VPS.const_get(m)
      end.select do |cls|
        ::Cult::VPS::Provider > cls
      end
    end

    def find_bundled(name)
      providers.find do |p|
        p.provider_name == name
      end
    end

    def find(name)
      find_bundled(name)
    end

  end
end

Cult::VPS.load_providers!
