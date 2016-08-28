require 'cult/driver'
require 'cult/named_array'

module Cult
  module Drivers

    module_function
    def load!
      Dir.glob(File.join(__dir__, "*_driver.rb")).each do |file|
        require file
      end
    end


    def all
      Cult::Drivers.constants(false).map do |m|
        Cult::Drivers.const_get(m)
      end.select do |cls|
        ::Cult::Driver > cls
      end.to_named_array
    end

  end
end

Cult::Drivers.load!
