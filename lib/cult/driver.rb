require 'cult/definition'

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
        "Cult::Driver/#{driver_name}"
      end
      alias_method :to_s, :inspect

      def named_array_identifier
        driver_name
      end
    end

    def inspect
      "\#<Cult::Driver \"#{self.class.driver_name}\">"
    end

    def to_s
      self.class.driver_name
    end

    # MikesKvmWarehouseDriver => mikes-kvm-warehouse

    # Attempts to loads all of the required gems before doing any real work
    def self.try_requires!
      begin
        Array(required_gems).each do |g|
          require g
        end
      rescue LoadError => e
        raise GemNeededError.new(Array(required_gems))
      end
    end

    def self.setup!
      try_requires!
    end

    def self.new(api_key:)
      try_requires!
      super
    end

    def self.for(project)
      conf = Definition.load(project.location_of('providers/default'))
      if (cls = Cult::VPS.find(conf['adapter']))
        cls.new(conf)
      end
    rescue Errno::ENOENT
      nil
    end
  end
end
