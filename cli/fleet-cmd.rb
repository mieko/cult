module Cult
  module CLI
    module_function
    def fleet_cmd
      fleet = Cri::Command.define do
        name 'fleet'
        summary 'Your fleet is the set of remote machines, each associated ' +
                'with a node.'
      end
      fleet
    end
  end
end
