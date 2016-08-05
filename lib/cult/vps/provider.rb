module Cult
  module VPS

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


    class Provider
      class << self
        attr_accessor :required_gems
      end

      # MyVpsProvider => my-vps-provider
      def self.provider_name
        name.split('::').last.gsub(/([a-z])([A-Z])/, '\1-\2').downcase
      end

      # Loads all of the required gems before calling initialize.  If it gets
      # a LoadError in the process, raises GemNeededError so the user can
      # be notified
      def self.new(*args)
        begin
          Array(required_gems).each do |g|
            require g
          end
        rescue LoadError => e
          raise GemNeededError.new(Array(required_gems))
        end
        super
      end

      def setup!
      end

      def self.for(project)
        json_file = project.location_of("providers/default.json")
        config = JSON.parse(File.read(json_file))
        if (cls = Cult::VPS.find(config['adapter']))
          cls.new(config)
        end
      rescue Errno::ENOENT
        nil
      end
    end

  end
end
