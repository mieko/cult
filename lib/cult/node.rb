module Cult
  class Node
    attr_accessor :path

    def initialize(path)
      @path = path
    end

    def name
      File.basename(path)
    end

    def roles
      json['roles']
    end

    def json
      @json ||= JSON.parse(File.read(json_file))
    end

    def json_file
      File.join(path, 'node.json')
    end

    def self.from_name(name)
      new(File.join(path, name))
    end

    def self.path
      File.join(Cult.project.path, "nodes")
    end

    def self.all_files
      Dir.glob(File.join(path, "*")).select do |file|
        Dir.exist?(file)
      end
    end

    def self.all
      return enum_for(__method__) unless block_given?

      all_files.map do |filename|
        new(filename).tap do |new_node|
          yield new_node if block_given?
        end
      end
    end
  end
end
