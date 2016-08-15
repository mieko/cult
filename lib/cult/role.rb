require 'tsort'

require 'cult/task'
require 'cult/artifact'
require 'cult/config'
require 'cult/definition'

module Cult
  class RoleNotFoundError < RuntimeError
    attr_reader :name
    def initialize(name)
      @name = name
    end

    def message
      "Role not found: #{name}"
    end
  end

  class Role
    attr_accessor :project
    attr_accessor :path

    def initialize(project, path)
      @project = project
      @path = path

      if Cult.immutable?
        definition
        parent_roles
        self.freeze
      end
    end

    def exist?
      Dir.exist?(path)
    end

    def name
      File.basename(path)
    end

    def collection_name
      class_name = self.class.name.split('::')[-1]
      class_name.downcase + 's'
    end

    def remote_path
      File.join(project.remote_path, collection_name, name)
    end

    def relative_path(obj_path)
      fail unless obj_path.start_with?(path)
      obj_path[path.size + 1 .. -1]
    end

    def inspect
      if Cult.immutable?
        "\#<#{self.class.name} id:#{object_id.to_s(36)} #{name.inspect}>"
      else
        "\#<#{self.class.name} #{name.inspect}>"
      end
    end
    alias_method :to_s, :inspect


    def hash
      [self.class, project, path].hash
    end


    def ==(rhs)
      [self.class, project, path] == [rhs.class, rhs.project, rhs.path]
    end
    alias_method :eql?, :==


    def tasks
      Task.all_for_role(project, self)
    end

    def artifacts
      Artifact.all_for_role(project, self)
    end

    def definition_parameters
      { project: project, role: self }
    end

    def definition
      @definition ||= begin
        Cult::Definition.load(definition_file, definition_parameters)
      end
    end

    def definition_file
      File.join(path, "role")
    end

    def includes
      definition['includes'] || definition['include'] ||
       (exist? ? ['all'] : [])
    end


    def parent_roles
      @parent_roles ||= begin
        includes.map do |name|
          Role.by_name(project, name)
        end
      end
    end


    def recursive_parent_roles(seen = [])
      result = []
      parent_roles.each do |role|
        next if seen.include?(role)
        seen.push(role)
        result.push(role)
        result += role.recursive_parent_roles(seen)
      end
      result
    end


    def tree
      [self] + recursive_parent_roles
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
      all_files(project).map do |filename|
        new(project, filename).tap do |new_role|
          yield new_role if block_given?
        end
      end
    end


    def build_order
      all_items = self.tree

      each_node = ->(&block) {
        all_items.each(&block)
      }

      each_child = ->(node, &block) {
        node.parent_roles.each(&block)
      }

      TSort.tsort(each_node, each_child).uniq
    end

    def has_role?(role)
      if role.is_a?(String)
        role = self.class.by_name(project, role)
      end
      build_order.include?(role)
    end
  end
end
