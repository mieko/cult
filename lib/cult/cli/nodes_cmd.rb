require 'cult/skel'

module Cult
  module CLI

    module_function
    def nodes_cmd
      nodes = Cri::Command.define do
        name 'nodes'
        summary 'Nodes are local representations of machines you\'ve ' +
                'got out there.'
      end

      node_create = Cri::Command.define do
        name 'create'
        usage 'create [options] NAME...'
        summary 'create a new node'
        option :r, :role, 'specify roles', argument: :required, multiple: true
        flag :P, :provision, 'provisions the server'

        run do |opts, args|
          puts "creating node #{args.inspect} with roles #{opts[:roles].inspect}"
          args.each do |arg|
            Skel.new(Cult.project).copy_template("nodes/template.json.erb",
                                                 "nodes/#{arg}/node.json")
          end
        end
      end
      nodes.add_command node_create

      node_list = Cri::Command.define do
        name 'list'
        summary 'list local nodes'

        run do |opts, args, cmd|
          puts "LIST!"
        end
      end
      nodes.add_command node_list

      return nodes
    end
  end
end
