require 'securerandom'
require 'cult/role'

module Cult
  module_function
  def project=(project)
    @project = project
  end

  def project
    @project
  end

  class Project
    CULT_FILENAME = '.cult'

    attr_reader :path
    attr_reader :cult_file

    def initialize(path)
      fail if path.match /\.cult/
      @path = path
      @cult_file = File.join(self.path, CULT_FILENAME)
    end

    def name
      File.basename(path)
    end

    def inspect
      "\#<#{self.class.name} name=#{name.inspect} path=#{path.inspect}>"
    end

    def location_of(file)
      File.join(path, file)
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
    end

    def roles
      Role.all(self)
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
  end
end
