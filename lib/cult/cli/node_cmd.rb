require 'securerandom'
require 'fileutils'
require 'json'

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
        usage       'ssh /NODE+/ [command...]'
        summary     'Starts an SSH shell to NODE'

        flag :i, :interactive,       "Force interactive mode"
        flag :I, :'non-interactive', "Force non-interactive mode"

        description <<~EOD.format_description
          With no additional arguments, initiates an interactive SSH connection
          to a node, authenticated with the node's public key.

          Additional arguments are passed to the 'ssh' command to allow for
          scripting or running one-off commands on the node.

          By default, cult assumes an interactive SSH session when no extra
          SSH arguments are passed, and a non-interactive session otherwise.
          You can force this behavior one way or the other with --interactive
          or --non-interactive.

          Cult will run SSH commands over all matching nodes in parallel if it
          considers your command non-interactive.
        EOD

        esc = ->(s) { Shellwords.escape(s) }

        run(arguments: 1 .. unlimited) do |opts, args, cmd|
          if opts[:interactive] && opts[:'non-interactive']
            fail CLIError, "can't specify --interactive and --non-interactive"
          end

          interactive = opts[:interactive] ||
                        (opts[:'non-interactive'] && false)

          nodes = CLI.fetch_items(args[0], from: Node)

          # With args, we'll assume it's a non-interactive session and run them
          # in parallel, otherwise, we'll assume it's interactive and force
          # them to run one at a time.
          ssh_extra = args[1 .. -1]
          interactive ||= ssh_extra.empty?
          concurrent = interactive || nodes.size == 1 ? 1 : nil

          Cult.paramap(nodes, concurrent: concurrent) do |node|
            # Through source control, etc, these sometimes end up with improper
            # permissions.  OpenSSH won't let us use it otherwise, and there's
            # no option to disable the check.
            File.chmod(0600, node.ssh_private_key_file)

            ssh_args = 'ssh', '-i', esc.(node.ssh_private_key_file),
                       '-p', esc.(node.ssh_port.to_s),
                       '-o', "UserKnownHostsFile=#{esc.(node.ssh_known_hosts_file)}",
                       esc.("#{node.user}@#{node.host}")
            ssh_args += ssh_extra
            # We used to use exec here, but with paramap, the forked process
            # has to live to long enough to report it's return value.
            system(*ssh_args)
            exit if interactive
          end
        end
      end
      node.add_command(node_ssh)

      node_new = Cri::Command.define do
        name        'new'
        usage       'new -r /ROLE+/ [options] NAME0 NAME1 ...'
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

        required :r, :role,      'Specify possibly multiple /ROLE+/',
                                  multiple: true
        required :n, :count,     'Generates <value> number of nodes'

        required :p, :provider,  'Use /PROVIDER/ to create the node'
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
              puts "Provisioning #{node.name}..."
              prov_data = provider.provision!(name: node.name,
                                              image: node_spec[:image],
                                              size: node_spec[:size],
                                              zone: node_spec[:zone],
                                              ssh_public_key: node.ssh_public_key_file)
              prov_data['provider'] = provider.name
              File.write(node.state_path, JSON.pretty_generate(prov_data))

              c = Commander.new(project: Cult.project, node: node)
              puts "Bootstrapping #{node.name}..."
              c.bootstrap!

              puts "Installing roles for #{node.name}..."
              c.install!(node)

              puts "Node installed: #{node.name}"
            end
          end

        end
      end
      node.add_command(node_new)

      node_rm = Cri::Command.define do
        name        'rm'
        usage       'rm /NODE+/ ...'
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
          concurrent = CLI.yes? ? :max : 1
          Cult.paramap(nodes, concurrent: concurrent) do |node|
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
            nil
          end
        end
      end
      node.add_command(node_rm)

      node_ls = Cri::Command.define do
        name        'ls'
        summary     'List nodes'
        usage       'ls /NODE*/ ...'
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

          Cult.paramap(nodes) do |node|
            role_string = node.build_order.reject(&:node?).map do |role|
              if node.zone_leader?(role)
                Rainbow('*' + role.name).cyan
              else
                role.name
              end
            end.join(' ')

            puts "#{node.name}\t#{node.provider&.name}\t" +
                "#{node.zone}\t#{node.addr(:public)}\t#{node.addr(:private)}\t" +
                "#{role_string}"
          end
        end
      end
      node.add_command(node_ls)


      node_sync = Cri::Command.define do
        name        'sync'
        usage       'sync /NODE*/ ...'
        summary     'Synchronize host information across fleet'
        description <<~EOD.format_description
          Computes, pre-processes, and executes "sync" tasks on every NODE,
          or all nodes if none are specified.

          Sync tasks are tasks that begin with 'sync-'.  They are meant to
          process dynamic information about the fleet well after a node has
          been created.  Typically, you'll run `cult node sync` to let each
          instance know about its new neighborhood after you add or remove
          new nodes.

          Sync tasks can optionally specify a "pass", with "sync-P0-..." or
          "sync-P1-...".  When `cult node sync` executes, it ensures that:

            1. On a given node, all tasks in the current pass are executed
               sequentially, in role and asciibetical order.

            2. Across the fleet, nodes which have tasks to run in a given pass
               are run concurently with each other.

            3. The entire fleet (or NODE selection) synchonizes between passes.
               "Pass 0" has run on EVERY node (across any role boundaries)
               before "Pass 1" is started on ANY node.

          Sync tasks without a specified pass are implicitly in "Pass 0".

          The sync can be restricted to a specified set of passes with the
          --pass option.  Note that this skips dependent passes.

          The sync can be restricted to a specified set of CONCRETE role tasks
          with the --role option.  No dependencies are considered: Cult
          calculates the tasks it would've ran, then removes all tasks not
          belonging to a role given to --roles
        EOD

        required :R, :role, "Skip sync tasks not in /ROLE/.  Can be specified " +
                            "more than once.",
                            multiple: true

        required :P, :pass, "Only execute PASS.  Can be specified more than " +
                            "once.",
                            multiple: true

        run(arguments: unlimited) do |opts, args, cmd|
          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(args, from: Node)
          roles = opts[:role].nil? ? Cult.project.roles
                                   : CLI.fetch_items(opts[:role], from: Role)
          c = CommanderSync.new(project: Cult.project, nodes: nodes)
          passes = opts[:pass] ? opts[:pass].map(&:to_i) : nil
          c.sync!(roles: roles, passes: passes)
        end
      end
      node.add_command(node_sync)

      node_ping = Cri::Command.define do
        name        'ping'
        summary     'Check the responsiveness of each node'
        usage       'ping /NODE*/'

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
        usage       'addr [/NODE+/ ...]'
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
