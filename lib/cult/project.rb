require 'securerandom'
require 'shellwords'
require 'json'
require 'yaml'

require 'cult/role'
require 'cult/provider'

module Cult
  class Project
    CULT_RC = '.cultrc'

    attr_reader :path
    attr_accessor :cult_version

    def initialize(path)
      @path = path
    end


    def name
      File.basename(path)
    end


    def cultrc
      location_of(CULT_RC)
    end


    def execute_cultrc
      load(cultrc)
    end


    def inspect
      "\#<#{self.class.name} name=#{name.inspect} path=#{path.inspect}>"
    end
    alias_method :to_s, :inspect


    def location_of(file)
      File.join(path, file)
    end


    def relative_path(obj_path)
      prefix = "#{path}/"

      if obj_path.start_with?(prefix)
        return obj_path[prefix.length .. -1]
      end

      fail ArgumentError, "#{path} isn't in the project"
    end


    def remote_path
      "cult"
    end


    def constructed?
      File.exist?(cultrc)
    end
    alias_method :exist?, :constructed?

    def nodes
      @nodes ||= begin
        Node.all(self)
      end
    end


    def roles
      @roles ||= begin
        Role.all(self)
      end
    end


    def providers
      @providers ||= begin
        Cult::Provider.all(self)
      end
    end

    attr_writer :default_provider
    def default_provider
      @default_provider ||= providers[0]
    end


    def drivers
      @drivers ||= begin
        Cult::Drivers.all
      end
    end


    def self.locate(path)
      path = File.expand_path(path)
      loop do
        return nil if path == '/'

        unless File.directory?(path)
          path = File.dirname(path)
        end

        candidate = File.join(path, CULT_RC)
        return new(path) if File.exist?(candidate)
        path = File.dirname(path)
      end
    end


    def self.from_cwd
      locate Dir.getwd
    end

    attr_accessor :git_integration
    alias_method :git?, :git_integration

    def git_branch
      res = %x(git -C #{Shellwords.escape(path)} branch --no-color)
      if res && (m = res.match(/^\* (.*)/))
        return m[1].chomp
      end
    end


    def dump_yaml?
      !! (ENV['CULT_DUMP'] || '').match(/^yaml$/i)
    end


    def dump_object(obj)
      dump_yaml? ? YAML.dump(obj) : JSON.pretty_generate(obj)
    end


    def dump_name(basename)
      basename + (dump_yaml? ? '.yml' : '.json')
    end


    def env
      ENV['CULT_ENV'] || begin
        if git_branch&.match(/\bdev(el(opment)?)?\b/)
          'development'
        else
          'production'
        end
      end
    end


    def development?
      env == 'development'
    end

  end
end
