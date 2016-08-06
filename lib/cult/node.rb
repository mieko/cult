require 'cult/role'

module Cult
  class Node < Role
    def self.path(project)
      File.join(project.path, 'nodes')
    end

    def definition_file
      File.join(path, 'node')
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

    alias_method :roles, :parent_roles
  end
end
