require 'tsort'

module Cult
  class Role
    include SingletonInstances

    def self.delegate_to_definition(method_name, definition_key = nil)
      definition_key ||= method_name
      define_method(method_name) do
        definition[definition_key.to_s]
      end
    end

    delegate_to_definition :user

    attr_accessor :project
    attr_accessor :path

    def initialize(project, path)
      @project = project
      @path = path
    end

    def node?
      false
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
      "\#<#{self.class.name} id:#{object_id.to_s(36)} #{name.inspect}>"
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


    def build_tasks
      tasks.select { |t| t.is_a?(Cult::BuildTask) }
    end


    def event_tasks
      tasks.select { |t| t.is_a?(Cult::EventTask) }
    end


    def artifacts
      Artifact.all_for_role(project, self)
    end
    alias_method :files, :artifacts

    def role_file
      File.join(path, "role.json")
    end

    def definition
      @definition ||= Definition.new(self)
    end


    def definition_path
      [ File.join(path, "extra.json"),
        role_file ]
    end


    def definition_parameters
      { project: project, role: self }
    end


    def definition_parents
      parent_roles
    end


    def includes
      definition.direct('includes') || ['base']
    end


    def parent_roles
      Array(includes).map do |name|
        Role.by_name(project, name)
      end.to_named_array
    end


    def recursive_parent_roles(seen = [])
      result = []
      parent_roles.each do |role|
        next if seen.include?(role)
        seen.push(role)
        result.push(role)
        result += role.recursive_parent_roles(seen)
      end
      result.to_named_array
    end


    def tree
      ([self] + recursive_parent_roles).to_named_array
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
      fail if block_given?
      all_files(project).map do |filename|
        new(project, filename)
      end.select(&:exist?).to_named_array
    end


    def build_order
      all_items = [self] + parent_roles

      each_node = ->(&block) {
        all_items.each(&block)
      }

      each_child = ->(node, &block) {
        node.parent_roles.each(&block)
      }

      TSort.tsort(each_node, each_child).to_named_array
    end


    def has_role?(role)
      ! tree[role].nil?
    end

    def names_for_role(*a)
      build_order.map(&:name)
    end

    def query_for_role
      build_order
    end

    def names_for_task
      tasks.map(&:name)
    end

  end
end
