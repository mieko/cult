require 'SecureRandom'
require 'fileutils'

module Cult
  module CLI

    module_function
    def node_cmd
      node = Cri::Command.define do
        optional_project
        name        'node'
        aliases     'nodes'
        summary     'Manage nodes'
        description <<~EOD.format_description
          The node commands manipulate your local index of nodes.  A node is
          conceptually description of a server.
        EOD

        run(arguments: none) do |opts, args, cmd|
          puts cmd.help
          exit
        end
      end

      node_ssh = Cri::Command.define do
        name        'ssh'
        usage       'ssh NODE'
        summary     'Starts an SSH shell to NODE'
        description <<~EOD.format_description
          With no additional arguments, initiates an interactive SSH connection
          to a node, authenticated with the node's public key.

          Additional arguments are passed to the 'ssh' command to allow for
          scripting or running one-off commands on the node..
        EOD

        esc = ->(s) { Shellwords.escape(s) }

        run(arguments: 1 .. unlimited) do |opts, args, cmd|
          node = CLI.fetch_item(args[0], from: Node)
          ssh_args = "ssh", '-i', esc.(node.ssh_private_key_file),
                     '-p', esc.(node.ssh_port.to_s),
                     '-o', "UserKnownHostsFile=#{esc.(node.ssh_known_hosts_file)}",
                     esc.("#{node.user}@#{node.host}")
          ssh_args += args[1 .. -1]
          exec(*ssh_args)
        end
      end
      node.add_command(node_ssh)

      node_new = Cri::Command.define do
        name        'new'
        usage       'new [options] NAME...'
        summary     'Create a new node'
        description <<~EOD.format_description
          This command creates a new node specification and then creates it with
          your provider.

          The newly created node will have all the roles listed in --role.  If
          none are specified, it'll have the role "base".  If no name is
          provided, it will be named after its role(s).

          If multiple names are provided, a new node is created for each name
          given.  The --count option is incompatible with multiple names given
          on the command line.

          The --count option lets you create an arbitrary amount of new nodes.
          The nodes will be identical, except they'll be named with arbitrary
          random suffixes, like:

          > web-fjfowhs7, web-48pqee6v

          And so forth.
        EOD

        required :r, :role,      'Specify possibly multiple roles',
                                  multiple: true
        required :n, :count,     'Generates <value> number of nodes'

        required :p, :provider,  'Provider'
        required :Z, :zone,      'Provider zone'
        required :I, :image,     'Provider image'
        required :S, :size,      'Provider instance size'

        run(arguments: unlimited) do |opts, args, cmd|
          random_suffix = ->(basename) do
            begin
              suffix = CLI.unique_id
              CLI.fetch_item("#{basename}-#{suffix}", from: Node, exist: false)
            rescue CLIError
              retry
            end
          end

          generate_sequenced_names = ->(name, n) do
            (0...n).map do
              random_suffix.(name)
            end
          end

          names = args.dup

          unless opts[:count].nil? || opts[:count].match(/^\d+$/)
            fail CLIError, "--count must be an integer"
          end

          if names.size > 1 && opts[:count]
            fail CLIError, "cannot specify both --count and more than one name"
          end

          roles = CLI.fetch_items(opts[:role] || 'base', from: Role)

          if names.empty?
            names.push roles.map(&:name).join("-")
            opts[:count] ||= 1
          end

          names = opts[:count] ? generate_sequenced_names.(names[0],
                                                           opts[:count].to_i)
                               : names

          # Makes sure they're all new.
          names = names.map do |name|
            CLI.fetch_item(name, from: Node, exist: false)
          end

          provider = if opts.key?(:provider)
            CLI.fetch_item(opts[:provider], from: Provider)
          else
            Cult.project.default_provider
          end

          # Use --size if it was specified, otherwise pull the
          # provider's default.
          node_spec = %i(size image zone).map do |m|
            value = opts[m] || provider.definition["default_#{m}"]
            fail CLIError, "No #{m} specified (and no default)" if value.nil?
            [m, value]
          end.to_h

          Cult.paramap(names) do |name|
            data = {
              name: name,
              roles: roles.map(&:name)
            }

            Node.from_data!(Cult.project, data).tap do |node|
              prov_data = provider.provision!(name: node.name,
                                              image: node_spec[:image],
                                              size: node_spec[:size],
                                              zone: node_spec[:zone],
                                              ssh_public_key: node.ssh_public_key_file)
              prov_data['provider'] = provider.name
              File.write(Cult.project.dump_name(node.state_path),
                         Cult.project.dump_object(prov_data))

              c = Commander.new(project: Cult.project, node: node)
              c.bootstrap!
              c.install!(node)
            end
          end

        end
      end
      node.add_command(node_new)

      node_rm = Cri::Command.define do
        name        'rm'
        usage       'rm NODE'
        summary     'Destroy nodes'
        description <<~EOD.format_description
          Destroys all nodes named NODE, or match the pattern described by
          NODE.

          First, the remote node is destroyed, then the local definition.

          This command respects the global --yes option, otherwise, you will
          be prompted before each destroy.
        EOD

        run(arguments: 1 .. unlimited) do |opts, args, cmd|
          nodes = CLI.fetch_items(args, from: Node)
          nodes.each do |node|
            if CLI.yes_no?("Destroy node `#{node}`?")
              puts "destroying #{node}"
              begin
                node.provider.destroy!(id: node.definition['id'],
                                       ssh_key_id: node.definition['ssh_key_id'])
              rescue Exception => e
                puts "Exception while remote-destroying node: #{e.to_s}\n" +
                     "#{e.backtrace}"
                puts "Continuing, though."
              end
              fail unless node.path.match(/#{Regexp.escape(node.name)}/)
              FileUtils.rm_rf(node.path)
            end
          end
        end
      end
      node.add_command(node_rm)

      node_ls = Cri::Command.define do
        aliases     'ls'
        summary     'List nodes'
        description <<~EOD.format_description
          This command lists the nodes in the project.
        EOD

        required :r, :role, 'List only nodes which include <value>',
                     multiple: true

        run(arguments: unlimited) do |opts, args, cmd|
          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(args, from: Node)

          if opts[:role]
            roles = CLI.fetch_items(opts[:role], from: Role)
            nodes = nodes.select do |n|
              roles.any? { |role| n.has_role?(role) }
            end
          end

          nodes.each do |node|
            puts "#{node.name}\t#{node.provider&.name}\t" +
                "#{node.zone}\t#{node.addr(:public)}\t#{node.addr(:private)}\t" +
                "#{node.roles.map(&:name)}"
          end
        end
      end
      node.add_command(node_ls)


      node_sync = Cri::Command.define do
        name        'sync'
        summary     'Synchronize host information across fleet'
        description <<~EOD.format_description
          Processes generates and executes tasks/sync on every node with a
          current network setup.
        EOD

        required :p, :pass, "Only execute pass PASS.  Can be specified " +
                            "more than once.",
                            multiple: true

        run(arguments: unlimited) do |opts, args, cmd|
          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(args, from: Node)
          c = CommanderSync.new(project: Cult.project, nodes: nodes)
          passes = opts[:pass] ? opts[:pass].map(&:to_i) : nil
          c.sync!(passes: passes)
        end
      end
      node.add_command(node_sync)

      node_ping = Cri::Command.define do
        name        'ping'
        summary     'Check the responsiveness of each node'
        usage       'ping NODES'

        flag :d, :destroy, 'Destroy nodes that are not responding.'

        description <<~EOD.format_description
          Connects to each node and reports health information.
        EOD

        run(arguments: unlimited) do |opts, args, cmd|
          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(args, from: Node)
          Cult.paramap(nodes) do |node|
            c = Commander.new(project: Cult.project, node: node)
            if (r = c.ping)
              puts Rainbow(node.name).green + ": #{r}"
              nil
            else
              puts Rainbow(node.name).red + ": Unreachable"
              node
            end
          end
        end
      end
      node.add_command(node_ping)

      node_addr = Cri::Command.define do
        name        'addr'
        aliases     'ip'
        summary     'print IP address of node'
        usage       'addr NODE'
        flag        :p, :private, 'Print private address'
        flag        :'6', :ipv6, 'Print ipv6 address'
        flag        :'4', :ipv4, 'Print ipv4 address'
        description <<~EOD.format_description
        EOD

        run(arguments: unlimited) do |opts, args, cmd|
          prot = Cult.project.default_ip_protocol
          if opts[:ipv4] && opts[:ipv6]
            fail CLIError, "can't specify --ipv4 and --ipv6"
          end

          prot = :ipv6 if opts[:ipv6]
          prot = :ipv4 if opts[:ipv4]

          priv = opts[:private] ? :private: :public

          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(args, from: Node)
          nodes.each do |node|
            puts node.addr(priv, prot)
          end
        end
      end
      node.add_command(node_addr)


      return node
    end
  end
end
