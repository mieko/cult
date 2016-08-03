require 'cri'

module Cult
  module CLI

    module_function
    def all_commands
      Dir.glob(File.join(__dir__, "*_cmd.rb")).each do |file|
        require file
      end

      Cult::CLI.methods(false).select do |m|
        m.to_s.match(/_cmd\z/)
      end.map do |m|
        Cult::CLI.send(m)
      end
    end

  end
end
