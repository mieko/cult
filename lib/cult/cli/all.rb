require 'cri'
require 'cult/cli/ext'

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

    def set_project(path)
      Cult.project = Cult::Project.locate(path)
      if Cult.project.nil?
        $stderr.puts "#{$0}: '#{path}' does not contain a valid cult project."
        exit 1
      end
    end

    def quiet=(v)
      @quiet = v
    end

    def quiet?(v)
      @quiet
    end

    def say(v)
      puts v unless @quiet
    end

    def yes=(v)
      @yes = v
    end

    def yes?
      @yes
    end

    def yes_no(msg)
      return true if yes?
      loop do
        print "#{msg} [Y]/n: "
        case $stdin.gets.chomp
          when '', /^[Yy]/
            return true
          when /^[Nn]/
            return false
          else
            $stderr.puts "Unrecognized response"
        end
      end
    end
  end
end

Cult::CLI.load_commands!
