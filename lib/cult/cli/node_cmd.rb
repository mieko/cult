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

        run(arguments: 0) do |opts, args, cmd|
          puts cmd.help
        end
      end

      node_ssh = Cri::Command.define do
        name        'ssh'
        usage       'ssh NODE'
        summary     'Starts an interactive SSH shell to NODE'
        description <<~EOD.format_description
        EOD

        esc = ->(s) { Shellwords.escape(s) }

        run(arguments: 1) do |opts, args, cmd|
          node = CLI.fetch_item(args[0], from: Node)
          exec "ssh", '-i', node.ssh_private_key_file,
               '-p', node.ssh_port.to_s,
               '-o', "UserKnownHostsFile=#{esc.(node.ssh_known_hosts_file)}",
               "#{node.user}@#{node.host}"
        end
      end
      node.add_command(node_ssh)

      node_create = Cri::Command.define do
        name        'create'
        aliases     'new'
        usage       'create [options] NAME...'
        summary     'Create a new node'
        description <<~EOD.format_description
          This command creates a new node specification and then creates it with
          your provider.

          The newly created node will have all the roles listed in --role.  If
          none are specified, it'll have the role "all".  If no name is
          provided, it will be named for its role(s).

          If multiple names are provided, a new node is created for each name
          given.

          The --count option lets you create an arbitrary amount of new nodes.
          The nodes will be identical, except they'll be named with increasing
          sequential numbers, like:

          > web-01, web-02

          And so forth.  The --count option is incompatible with multiple names
          given on the command line.  If --count is specified with one name, the
          name will become the prefix for all nodes created.  If --count is
          specified with no names, the prefix will be generated from the role
          names used, as discussed above.
        EOD

        required :r, :role,      'Specify possibly multiple roles',
                                  multiple: true
        required :n, :count,     'Generates <value> number of nodes'

        required :p, :provider,  'Provider'
        required :Z, :zone,      'Provider zone'
        required :I, :image,     'Provider image'
        required :S, :size,      'Provider instance size'

        run(arguments: 0..-1) do |opts, args, cmd|
          random_suffix = ->(basename) do
            begin
              suffix = CLI.unique_id
              CLI.fetch_item("#{basename}-#{suffix}", from: Node, exist: false)
            rescue CLIError
              retry
            end
          end

          generate_sequenced_names = ->(name, n) do
            result = []
            result.push(random_suffix.(name)) until result.size == n
            result
          end

          unless opts[:count].nil? || opts[:count].match(/^\d+$/)
            fail CLIError, "--count must be an integer"
          end

          names = args.dup

          roles = opts[:role] ? CLI.fetch_items(opts[:role], from: Role) : []

          if roles.empty?
            roles = CLI.fetch_items('all', from: Role)
            if names.empty?
              begin
                names.push CLI.fetch_item('node', from: Node, exist: false)
              rescue
                names.push random_suffix.('node')
              end
            end
          end

          if names.size > 1 && opts[:count]
            fail CLIError, "cannot specify both --count and more than one name"
          end

          if names.empty? && !roles.empty?
            names.push roles.map(&:name).sort.join('-')
          end

          if opts[:count]
            names = generate_sequenced_names.(names[0], opts[:count].to_i)
          end

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

          nodes = names.map do |name|
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
      node.add_command node_create

      node_destroy = Cri::Command.define do
        name        'destroy'
        aliases     'rm'
        usage       'destroy NODE'
        summary     'Destroy nodes'
        description <<~EOD.format_description
          Destroys all nodes named NODE, or match the pattern described by
          NODE.

          First, the remote node is destroyed, then the local definition.

          This command respects the global --yes option, otherwise, you will
          be prompted before each destroy.
        EOD

        run(arguments: 1..-1) do |opts, args, cmd|
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
      node.add_command(node_destroy)

      node_list = Cri::Command.define do
        name        'list'
        aliases     'ls'
        summary     'List nodes'
        description <<~EOD.format_description
          This command lists the nodes in the project.
        EOD

        required :r, :role, 'List only nodes which include <value>',
                     multiple: true

        run(arguments: 0..1) do |opts, args, cmd|
          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(*args, from: Node)

          if opts[:role]
            roles = CLI.fetch_items(opts[:role], from: Role)
            nodes = nodes.select do |n|
              roles.any? { |role| n.has_role?(role) }
            end
          end

          nodes.each do |node|
            puts "#{node.name}\t#{node.provider&.name}\t#{node.roles.map(&:name)}"
          end
        end
      end
      node.add_command node_list


      node_sync = Cri::Command.define do
        name        'sync'
        summary     'Synchronize host information across fleet'
        description <<~EOD.format_description
          Processes generates and executes tasks/sync on every node with a
          current network setup.
        EOD

        run(arguments: 0..-1) do |opts, args, cmd|
          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(args, from: Node)
          nodes.each do |node|
            c = Commander.new(project: Cult.project, node: node)
            c.sync!
            puts "SYNCING #{node}"
          end
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

        run(arguments: 0..-1) do |opts, args, cmd|
          nodes = args.empty? ? Cult.project.nodes
                              : CLI.fetch_items(args, from: Node)
          unresponsive = nodes.map do |node|
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


      return node
    end
  end
end
