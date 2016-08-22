require 'cult/skel'
require 'cult/commander'

module Cult
  module CLI

    module_function
    def node_cmd
      node = Cri::Command.define do
        optional_project
        name        'node'
        aliases     'nodes'
        summary     'Manage nodes'
        description <<~EOD
          The node commands manipulate your local index of nodes.  A node is
          conceptually description of a server.
        EOD

        run do |opts, args, cmd|
          CLI.require_args(args, 0)
          puts cmd.help
          exit 0;
        end
      end

      node_ssh = Cri::Command.define do
        name    'ssh'
        usage   'ssh NODE'
        summary 'Starts an interactive SSH shell to NODE'

        run do |opts, args, cmd|
          CLI.require_args(args, 1)

          node = fetch_item(args[0], from: Node)
          exec "ssh", "#{node.user}@#{node.host}"
        end
      end
      node.add_command(node_ssh)

      node_bootstrap = Cri::Command.define do
        name        'bootstrap'
        usage       'bootstrap NODE'
        summary     'Executes bootstrap tasks on NODE'
        description <<~EOD
        'cult node bootstrap NODE' takes an existing node (which has been
        provisioned), and runs all tasks in the "bootstrap" role on it.

        This command is used primarily for testing the bootstrap process in
        isolation, as 'cult node create -p NAME' creates, provisions, and then
        bootstraps a node from the ground up.
        EOD

        run do |opts, args, cmd|
          CLI.require_args(args, 1..-1)

          nodes = args.map { |a| CLI.fetch_items(a, from: Node) }.flatten

          nodes.each do |node|
            ctrl = Commander.new(project: Cult.project, node: node)
            ctrl.bootstrap!
          end
        end
      end
      node.add_command(node_bootstrap)

      node_create = Cri::Command.define do
        name        'create'
        usage       'create [options] NAME...'
        summary     'Create a new node'
        description <<~EOD
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
        flag     :p, :provision, 'Provision created node'
        flag     :b, :bootstrap, 'Provision and bootstrap created node'
        required :n, :count,     'Generates <value> number of nodes'

        # FIXME
        run do |opts, args, cmd|
          opts[:bootstrap] = true if opts[:migrate]
          opts[:provision] = true if opts[:bootstrap]
          puts "creating node #{args.inspect} with roles #{opts[:roles].inspect}"

          args.each do |arg|
            node = nil
            if opts[:provision]
              provdata = Cult.project.provider.provision!(name: arg, spec_name: 'small')
              node = Node.create_from_provision!(Cult.project, provdata)
            end

            if opts[:bootstrap]
              control = Cult::Commander.new(project: Cult.project, node: node)
              control.bootstrap!
            end
          end
        end
      end
      node.add_command node_create

      node_list = Cri::Command.define do
        name        'list'
        summary     'List nodes'
        description <<~EOD
          This command lists the nodes in the project.
        EOD

        required :r, :role, 'List only nodes which include <value>'


        run do |opts, args, cmd|
          CLI.require_args(args, 0..1)

          nodes = Cult.project.nodes

          # Filter by names
          if args[0]
            nodes = nodes.all(args[0])
          end

          if opts[:role]
            role = CLI.fetch_item(opts[:role], from: Role)
            nodes = nodes.select {|n| n.has_role?(role) }
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
