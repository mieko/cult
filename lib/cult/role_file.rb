require 'cult/quick_erb'

module Cult
  class RoleFile
    attr_reader :path
    attr_reader :role
    attr_reader :name

    def initialize(role, path)
      @role = role
      @path = path
      @name = File.basename(path)
    end

    def inspect
      "\#<#{self.class.name} role:#{role&.name.inspect} name:#{name.inspect}>"
    end
    alias_method :to_s, :inspect

    def content(project, role, node)
      erb = Cult::QuickErb.new(project: project, role: role, node: node)
      erb.process File.read(path)
    end

    def self.for_role(project, role)
      Dir.glob(File.join(role.path, "files", "**/*")).map do |filename|
        next if File.directory?(filename)
        new(role, filename).tap do |new_role_file|
          yield new_role_task if block_given?
        end
      end.compact
    end

  end
end
