require 'cult/role'
require 'fileutils'
require 'shellwords'

module Cult
  class Node < Role
    def self.from_data!(project, data)
      node = by_name(project, data[:name])
      raise Errno::EEXIST if node.exist?

      FileUtils.mkdir_p(node.path)
      File.write(project.dump_name(node.node_path),
                 project.dump_object(data))

      node.generate_ssh_keys!

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


    def ssh_public_key_file
      File.join(path, 'ssh.pub')
    end

    def ssh_private_key_file
      File.join(path, 'ssh.key')
    end

    def generate_ssh_keys!
      esc = ->(s) { Shellwords.escape(s) }
      tmp_public = ssh_private_key_file + '.pub'

      # Wanted to use -o and -t ecdsa, but Net::SSH still has some
      # issues with ECDSA, and only 4.0 beta supports -o style new keys
      cmd = "ssh-keygen -N '' -t rsa -b 4096 -C #{esc.(name)} " +
            "-f #{esc.(ssh_private_key_file)} && " +
            "mv #{esc.(tmp_public)} #{esc.(ssh_public_key_file)}"
      %x(#{cmd})
      unless $?.success?
        fail "Couldn't generate SSH key, command: #{cmd}"
      end
    end
    private :generate_ssh_keys!

  end
end
