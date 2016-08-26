require 'cult/named_array'
require 'cult/definition'

require 'forwardable'

module Cult
  class Provider
    extend Forwardable

    def_delegators :driver, :sizes, :images, :zones, :provision!, :destroy!

    attr_reader :project
    attr_reader :path


    def initialize(project, path)
      @project = project
      @path = path
    end


    def name
      File.basename(path)
    end


    def inspect
      prelude = "#{self.class.name} \"#{name}\""
      driver_name = driver.class.driver_name
      driver_string = (driver_name == name) ? '' : " driver=\"#{driver_name}\""
      "\#<#{prelude}#{driver_string}>"
    end


    def driver
      @driver ||= begin
        cls = project.drivers[definition['driver']]
        cls.new(api_key: definition['api_key'])
      end
    end


    def definition
      @definition ||= Definition.new(self)
    end


    def definition_path
      File.join(path, "provider")
    end


    def definition_parameters
      { project: self.project }
    end


    def self.path(project)
      project.location_of("providers")
    end


    def self.all_files(project)
      Dir.glob(File.join(path(project), "*")).select do |file|
        Dir.exist?(file)
      end
    end


    def self.all(project)
      all_files(project).map do |filename|
        new(project, filename)
      end.to_named_array
    end
  end
end
