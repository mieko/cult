require 'cult/transferable'

module Cult
  class Artifact
    include Transferable

    def self.collection_name
      "files"
    end

    def relative_path
      name
    end

    attr_reader :path
    attr_reader :role

    def initialize(role, path)
      @role = role
      @path = path
    end


    def inspect
      "\#<#{self.class.name} role:#{role&.name.inspect} name:#{name.inspect}>"
    end
    alias_method :to_s, :inspect

    def self.all_for_role(project, role)
      Dir.glob(File.join(role.path, "files", "**/*")).map do |filename|
        next if File.directory?(filename)
        new(role, filename).tap do |new_file|
          yield new_file if block_given?
        end
      end.compact
    end

  end
end
