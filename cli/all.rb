require 'cri'

Dir.glob(File.join(File.dirname(__FILE__), "*-cmd.rb")).each do |file|
  require file
end

module Cult
  module CLI

    module_function
    def all_commands
      Cult::CLI.methods(false).select do |m|
        m.to_s.match(/_cmd\z/)
      end.map do |m|
        Cult::CLI.send(m)
      end
    end

  end
end
