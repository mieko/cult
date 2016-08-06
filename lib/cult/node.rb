require 'cult/role'

module Cult
  class Node < Role
    def self.path(project)
      File.join(project.path, 'nodes')
    end

    def json_file
      File.join(path, 'node.json')
    end

    def includes
      json['roles'] || super
    end

    def host
      json['host']
    end

    alias_method :roles, :parent_roles
  end
end
