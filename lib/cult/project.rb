require 'securerandom'
require 'shellwords'

require 'cult/config'
require 'cult/role'
require 'cult/provider'

module Cult
  class Project
    CULT_FILENAME = '.cult'

    attr_reader :path
    attr_reader :cult_file

    def initialize(path)
      fail if path.match /\.cult/
      @path = path
      @cult_file = File.join(self.path, CULT_FILENAME)

      if Cult.immutable?
        self.provider
        self.freeze
      end
    end

    def name
      File.basename(path)
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
      File.exist?(cult_file)
    end

    def construct!
      FileUtils.mkdir_p(path) unless Dir.exist?(path)
      FileUtils.cp_r()
      create_cult_file!
    end

    def create_cult_file!
      File.write(cult_file, SecureRandom.hex(8))
    end

    def cult_id
      @cult_id ||= begin
        File.read(cult_file).chomp
      rescue
        nil
      end
    end

    def nodes
      Node.all(self)
    end

    def roles
      Role.all(self)
    end

    def providers
      Cult::Provider.all(self)
    end

    def drivers
      Cult::Drivers.all
    end

    def self.locate(path)
      path = File.expand_path(path)
      loop do
        return nil if path == '/'

        unless File.directory?(path)
          path = File.dirname(path)
        end

        candidate = File.join(path, CULT_FILENAME)
        return new(path) if File.exist?(candidate)
        path = File.dirname(path)
      end
    end

    def self.from_cwd
      locate Dir.getwd
    end

    def git_branch
      res = %x(git -C #{Shellwords.escape(path)} branch --no-color)
      if res && (m = res.match(/^\* (.*)/))
        return m[1].chomp
      end
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
