module Cult
  module CLI
    module_function
    def fleet_cmd
      fleet = Cri::Command.define do
        name 'fleet'
        summary 'Fleet commands'

        run(arguments: 0) do |opts, args, cmd|
          puts cmd.help
        end
      end

      fleet_sync = Cri::Command.define do
        name    'sync'
        summary 'Synchronize host information across fleet'
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
      fleet.add_command(fleet_sync)

      fleet
    end
  end
end
