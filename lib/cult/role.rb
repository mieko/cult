require 'json'

require 'cult/task'

module Cult
  class Role
    attr_accessor :project
    attr_accessor :path

    def initialize(project, path)
      @project = project
      @path = path
    end

    def name
      File.basename(path)
    end

    def inspect
      "\#<#{self.class.name} #{name.inspect}>"
    end

    alias_method :to_s, :inspect

    def ==(rhs)
      [project, path] == [rhs.project, rhs.path]
    end

    def tasks
      Task.for_role(self)
    end

    def json
      @json ||= begin
        defaults = default_json
        if File.exist?(json_file)
          defaults.merge(JSON.parse(File.read(json_file)))
        else
          defaults
        end
      end
    end

    def includes
      json['include'] || json['includes'] || json['roles'] || json['_includes']
    end

    def parent_roles
      @parent_roles ||= begin
        includes.map do |name|
          Role.by_name(project, name)
        end
      end
    end

    def complete_parent_roles(seen = [])
      result = []
      parent_roles.each do |role|
        next if seen.include?(role)
        seen.push(role)
        result.push(role)
        result += role.complete_parent_roles(seen)
      end
      result
    end

    def tree
      [self] + complete_parent_roles
    end

    def default_json
      {'_includes': ['all']}
    end

    def json_file
      File.join(path, "role.json")
    end

    def self.by_name(project, name)
      new(project, File.join(path(project), name))
    end

    def self.path(project)
      File.join(project.path, "roles")
    end

    def self.all_files(project)
      Dir.glob(File.join(path(project), "*")).select do |file|
        Dir.exist?(file)
      end
    end

    def self.all(project)
      return enum_for(__method__, project) unless block_given?
      all_files(project).map do |filename|
        new(project, filename).tap do |new_role|
          yield new_role if block_given?
        end
      end
    end
  end
end
