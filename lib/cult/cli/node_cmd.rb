require 'cult/skel'

module Cult
  module CLI

    module_function
    def node_cmd
      node = Cri::Command.define do
        name        'node'
        summary     'Manage nodes'
        description <<~EOD
          The node commands manipulate your local index of nodes.  A node is
          conceptually description of a server.
        EOD

        run do |_, _, cmd|
          puts cmd.help
          exit 0;
        end
      end

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
        flag     :p, :provision, 'Provision and bootstrap the created node'
        required :n, :count,     'Generates <value> number of nodes'

        run do |opts, args|
          puts "creating node #{args.inspect} with roles #{opts[:roles].inspect}"
          # TODO: Operate as described above
          args.each do |arg|
            Skel.new(Cult.project).copy_template("nodes/node-template.json.erb",
                                                 "nodes/#{arg}/node.json")
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
          # TODO
          puts "LIST!"
        end
      end
      node.add_command node_list

      return node
    end
  end
end
