require 'cult/vps/provider'

module Cult
  module VPS

    module_function
    def load_providers!
      Dir.glob(File.join(__dir__, "*.rb")).each do |file|
        next if file == __FILE__
        next if File.basename(file) == 'provider.rb'
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

    def find_third_party(name)
      begin
        require "cult/vps/#{name.gsub('-', '_')}"
        cls_name = name.capitalize.gsub(/([a-z])[_-]([a-z])/) do |s| "
          #{m[0]}#{m[2].upcase}"
        end
        Cult::VPS.const_get(cls_name)
      rescue LoadError
        nil
      end
    end

    def find(name)
      find_bundled(name) || find_third_party(name)
    end

  end
end

Cult::VPS.load_providers!
