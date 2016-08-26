require 'cult/role'
require 'fileutils'

module Cult
  class Node < Role
    def self.from_data!(project, data)
      node = by_name(project, data[:name])
      raise Errno::EEXIST if node.exist?

      FileUtils.mkdir_p(node.path)
      File.write(project.dump_name(node.node_path),
                 project.dump_object(data))
      return by_name(project, data[:name])
    end

    # These are convenience methods for templates, etc.
    # delegate them to the definition.
    %i(user host ipv4_public ipv4_private ipv6_public ipv6_private).each do |m|
      define_method(m) do
        definition[m.to_s]
      end
    end


    def self.path(project)
      File.join(project.path, 'nodes')
    end


    def node_path
      File.join(path, 'node')
    end


    def state_path
      File.join(path, 'state')
    end


    def definition_path
      [ node_path, state_path ]
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


    alias_method :roles, :parent_roles
  end
end
