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
      [File.join(path, "provider"), File.join(path, "defaults")]
    end


    def definition_parameters
      { project: self.project }
    end

    def definition_parents
      []
    end


    # Chooses the smallest size setup with Ubuntu > Debian > Redhat,
    # and a random zone.
    def self.generate_defaults(definition)
      definition = JSON.parse(definition.to_json)
      text_to_mb = ->(text) {
        multipliers = {
          mb: 1 ** 1,
          gb: 1 ** 2,
          tb: 1 ** 3,
          pb: 1 ** 4
        }
        if (m = text.match(/(\d+)([mgtp]b)/))
          base = m[1].to_i
          mul = multipliers.fetch(m[2].to_sym)
          base * mul
        else
          nil
        end
      }

      conf = definition['configurations']

      # select the smallest size
      size = conf['sizes'].map do |size|
        if mb = text_to_mb.(size)
          [mb, size]
        else
          nil
        end
      end.compact.sort_by(&:first).last.last

      image = conf['images'].sort_by do |i|
        case i
          when /ubuntu-(\d+)-(\d+)/;
            10000 + ($1.to_i * 100) + ($2.to_i * 10)
          when /debian-(\d+)/
            9000 + ($1.to_i * 100)
          when /(redhat|centos|fedora)-(\d+)/
            8000 + ($2.to_i * 100)
          else
            1
        end
      end.last

      zone = conf['zones'].sample

      {
        default_size:  size,
        default_zone:  zone,
        default_image: image
      }
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
