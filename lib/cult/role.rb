require 'json'

require 'cult/task'
require 'cult/config'

module Cult
  class Role
    attr_accessor :project
    attr_accessor :path

    def initialize(project, path)
      @project = project
      @path = path

      if Cult.immutable?
        json
        parent_roles
        self.freeze
      end
    end

    def name
      File.basename(path)
    end

    def inspect
      if Cult.immutable?
        "\#<#{self.class.name} id:#{object_id.to_s(36)} #{name.inspect}>"
      else
        "\#<#{self.class.name} #{name.inspect}>"
      end
    end

    alias_method :to_s, :inspect

    def ==(rhs)
      [self.class, project, path] == [rhs.class, rhs.project, rhs.path]
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
      json['includes'] || json['include'] || ['all']
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
      {}
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

    if Cult.immutable?
      def self.cache_get(cls, *args)
        @singletons ||= {}
        key = [cls, *args]

        if (rval = @singletons[key])
          return rval
        end

        return nil
      end

      def self.cache_put(obj, *args)
        @singletons ||= {}
        key = [obj.class, *args]
        @singletons[key] = obj
        obj
      end

      def self.new(*args)
        if (result = cache_get(self, *args))
          return result
        else
          result = super
          cache_put(result, *args)
          return result
        end
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
