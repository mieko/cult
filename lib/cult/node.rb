require 'fileutils'
require 'shellwords'

require 'cult/role'

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

    delegate_to_definition :host
    delegate_to_definition :zone
    delegate_to_definition :ipv4_public
    delegate_to_definition :ipv4_private
    delegate_to_definition :ipv6_public
    delegate_to_definition :ipv6_private


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


    def provider
      project.providers[definition['provider']]
    end


    def names_for_provider
      [ provider&.name ]
    end

    alias_method :roles, :parent_roles


    def ssh_public_key_file
      File.join(path, 'ssh.pub')
    end


    def ssh_private_key_file
      File.join(path, 'ssh.key')
    end

    def ssh_known_hosts_file
      File.join(path, 'ssh.known-host')
    end

    def ssh_port
      # Moving SSH ports for security is lame.
      definition['ssh_port'] || 22
    end


    def addr(access, protocol = project.default_ip_protocol)
      fail ArgumentError unless [:public, :private].include?(access)
      fail ArgumentError unless [:ipv4, :ipv6].include?(protocol)
      send("#{protocol}_#{access}")
    end


    def same_network?(other)
      [provider, zone] == [other.provider, other.zone]
    end


    def addr_from(other, protocol = project.default_ip_protocol)
      same_network?(other) ? addr(:private, protocol) : addr(:public, protocol)
    end


    def provider_peers
      project.nodes.with(provider: provider).reject do |n|
        n == self
      end
    end


    def zone_peers
      provider_peers.with(zone: zone)
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

  end
end
