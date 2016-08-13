require 'cri'

# This extends Cri::Command to, by default, require a project when a command
# is run.  This can be overridden with no_project

module Cult
  module CLI
    module CommandExtensions
      def project_required?
        defined?(@project_required) ? @project_required : true
      end

      def project_required=(v)
        @project_required = v
      end

      def run_this(*)
        if project_required? && Cult.project.nil?
          $stderr.puts "#{$0}: command '#{name}' requires a cult project"
          exit 1
        end
        super
      end
    end

    module CommandDSLExtensions
      def no_project
        @command.project_required = false
      end
    end
  end
end

Cri::Command.prepend(Cult::CLI::CommandExtensions)
Cri::CommandDSL.prepend(Cult::CLI::CommandDSLExtensions)
