require 'cult/role'
require 'fileutils'

module Cult
  class Node < Role
    def self.create_from_provision!(project, provision_data)
      node = by_name(project, provision_data[:name])
      raise Errno::EEXIST if node.exist?
      FileUtils.mkdir_p(node.path)

      data = provision_data.dup
      extra = data.delete(:extra)
      File.write(project.dump_name(node.definition_file), project.dump_object(data))
      File.write(project.dump_name(node.extra_file), project.dump_object(extra))
      return node
    end


    def self.path(project)
      File.join(project.path, 'nodes')
    end


    def definition_path
      File.join(path, 'node')
    end


    def definition_parameters
      super.merge(node: self)
    end


    def extra_file
      File.join(path, 'extra')
    end


    def includes
      definition.direct('roles') || super
    end


    def host
      definition['host']
    end


    def user
      definition['user']
    end

    alias_method :roles, :parent_roles
  end
end
