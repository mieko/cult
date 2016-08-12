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
      File.write(node.definition_file + '.json', JSON.pretty_generate(data))
      File.write(node.extra_file + '.json', JSON.pretty_generate(extra))
      return node
    end

    def self.path(project)
      File.join(project.path, 'nodes')
    end

    def definition_file
      File.join(path, 'node')
    end

    def extra_file
      File.join(path, 'extra')
    end

    def definition_parameters
      super.merge(node: self)
    end

    def includes
      definition['roles'] || super
    end

    def host
      definition['host']
    end

    def user
      definition['user'] || 'cult'
    end

    alias_method :roles, :parent_roles
  end
end
