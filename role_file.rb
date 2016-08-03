module Cult
  class RoleFile
    attr_accessor :path

    def initialize(path)
      @path = path
    end

    def name
      File.basename(path)
    end

    def self.generate(name)
      new(File.join(path, name))
    end

    def self.path
      File.join(Cult.project.path, "roles")
    end

    def self.all_files
      Dir.glob(File.join(path, "*")).select do |file|
        Dir.exist?(file)
      end
    end

    def self.all
      return enum_for(__method__) unless block_given?
      all_files.map do |filename|
        new(filename).tap do |new_role|
          yield new_role if block_given?
        end
      end
    end
  end
end
