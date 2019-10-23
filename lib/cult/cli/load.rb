require 'cri'
require 'cult/cli/cri_extensions'

module Cult
  module CLI
    module_function

    def load_commands!
      Dir.glob(File.join(__dir__, "*_cmd.rb")).each do |file|
        require file
      end
    end

    def commands
      Cult::CLI.methods(false).select do |m|
        m.to_s.match(/_cmd\z/)
      end.map do |m|
        Cult::CLI.send(m)
      end
    end
  end
end

Cult::CLI.load_commands!
