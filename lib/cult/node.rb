require 'fileutils'
require 'shellwords'
require 'json'

require 'cult/role'

module Cult
  class Node < Role
    class << self
      attr_accessor :marshal_exclude
    end

    self.marshal_exclude = [:@project]

    def marshal_dump
      instance_variables.reject do |key|
        self.class.marshal_exclude.include?(key)
      end.map do |key|
        [key, instance_variable_get(key)]
      end.to_h
    end

    def marshal_load(vars)
      vars.each do |key, value|
        unless self.class.marshal_exclude.include?(key)
          instance_variable_set(key, value)
        end
      end
      self.project = Cult.project
    end

    def self.from_data!(project, data)
      node = by_name(project, data[:name])
      raise Errno::EEXIST if node.exist?

      FileUtils.mkdir_p(node.path)
      File.write(node.node_path, JSON.pretty_generate(data))

      node.generate_ssh_keys!

      by_name(project, data[:name])
    end

    delegate_to_definition :host
    delegate_to_definition :zone
    delegate_to_definition :size
    delegate_to_definition :image
    delegate_to_definition :provider_name, :provider
    delegate_to_definition :ipv4_public
    delegate_to_definition :ipv4_private
    delegate_to_definition :ipv6_public
    delegate_to_definition :ipv6_private
    delegate_to_definition :created_at

    def node?
      true
    end

    def self.path(project)
      File.join(project.path, 'nodes')
    end

    def node_path
      File.join(path, 'node.json')
    end

    def exist?
      File.exist?(state_path)
    end

    def state_path
      File.join(path, 'state.json')
    end

    def definition_path
      [extra_path, state_path, node_path]
    end

    def definition_parameters
      super.merge(node: self)
    end

    def extra_path
      File.join(path, 'extra.json')
    end

    def includes
      definition.direct('roles') || super
    end

    def provider
      project.providers[provider_name]
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

    def generate_ssh_keys!
      esc = ->(s) { Shellwords.escape(s) }
      tmp_public = ssh_private_key_file + '.pub'

      # Wanted to use -o and -t ecdsa, but Net::SSH still has some
      # issues with ECDSA, and only 4.0 beta supports -o style new keys
      cmd = "ssh-keygen -N '' -t ed25519 -C #{esc.call(name)} " \
            "-f #{esc.call(ssh_private_key_file)} && " \
            "mv #{esc.call(tmp_public)} #{esc.call(ssh_public_key_file)}"
      %x(#{cmd})

      unless $?.success?
        fail "Couldn't generate SSH key, command: #{cmd}"
      end

      File.chmod(0o600, ssh_private_key_file)
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

    def cluster(*preds)
      unless (preds - [:provider, :zone]).empty?
        fail ArgumentError, "invalid predicate: #{preds.inspect}"
      end

      preds.push(:provider) if preds.include?(:zone)

      col = project.nodes
      preds.each do |pred|
        col = col.select do |v|
          v.send(pred) == send(pred)
        end
      end
      col
    end

    def peers(*preds)
      cluster(*preds).reject { |v| v == self }
    end

    def provider_peers
      peers(:provider)
    end

    def leader(role, *preds)
      c = cluster(*preds)
      c = c.with(role: role) if role
      c = c.sort_by(&:created_at)
      c.first
    end

    def role_leader(role)
      leader(role)
    end

    def role_leader?(role)
      role_leader(role) == self
    end

    def provider_leader(role = nil)
      leader(role, :provider)
    end

    def provider_leader?(role = nil)
      provider_leader(role) == self
    end

    def zone_leader(role = nil)
      leader(role, :zone)
    end

    def zone_leader?(role = nil)
      zone_leader(role) == self
    end

    def zone_peers
      peers(:zone)
    end

    def names_for_provider
      [provider_name]
    end

    def names_for_zone
      [zone]
    end
  end
end
