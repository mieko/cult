require 'cult/definition'
require 'cult/drivers/common'

module Cult
  class Driver

    # This is raised when a Driver is instantiated,  but the required
    # gems are not installed.
    class GemNeededError < RuntimeError
      attr_reader :gems
      def initialize(gems)
        @gems = gems
        super(message)
      end

      def message
        "gems required: #{gems.inspect}"
      end
    end

    class << self
      attr_accessor :required_gems

      def driver_name
        name.split('::')
            .last
            .sub(/Driver\z/, '')
            .gsub(/([a-z])([A-Z])/, '\1-\2')
            .downcase
      end

      def inspect
        self == Driver ? super : "#{super}/#{driver_name}"
      end
      alias_method :to_s, :inspect

      def named_array_identifier
        driver_name
      end
    end

    def inspect
      "\#<#{self.class.name} \"#{self.class.driver_name}\">"
    end

    def to_s
      self.class.driver_name
    end

    # Attempts to loads all of the required gems before doing any real work
    def self.try_requires!
      req = Array(required_gems).map do |gem|
        begin
          require gem
          nil
        rescue LoadError
          gem
        end
      end.compact

      unless req.empty?
        fail GemNeededError.new(req)
      end
    end


    # These are helpers that most implementations will need, but Driver itself
    # doesn't depend on.  Things like exponential back-off, awaiting an SSH
    # port to open, etc.
    include ::Cult::Drivers::Common


    def self.setup!
      try_requires!
    end


    def self.new(api_key:)
      try_requires!
      super
    end
  end
end
