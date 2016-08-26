require 'cult/skel'
require 'cult/commander'

require 'SecureRandom'

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

        run(arguments: 1) do |opts, args, cmd|
          node = CLI.fetch_item(args[0], from: Node)
          exec "ssh", "#{node.user}@#{node.host}"
        end
      end
      node.add_command(node_ssh)

      node_create = Cri::Command.define do
        name        'create'
        aliases     'new'
        usage       'create [options] NAME...'
        summary     'Create a new node'
        description <<~EOD.format_description
          This command creates a new node specification.  With --bootstrap,
          it'll also provision it, so it'll actually exist out there.

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
        required :p, :provider,  'Provider'
        required :n, :count,     'Generates <value> number of nodes'

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

          nodes = names.map do |name|
            puts [name, roles, provider].inspect
          end
        end
      end
      node.add_command node_create

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
            puts "Node: #{node.inspect}"
          end
        end
      end
      node.add_command node_list

      return node
    end
  end
end
