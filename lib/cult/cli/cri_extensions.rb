require 'cri'

module Cult
  module CLI
    class ::String
      def format_description
        self
      end
    end

    module CommandExtensions
      def project_required?
        defined?(@project_required) ? @project_required : true
      end

      def project_required=(v)
        @project_required = v
      end

      attr_accessor :argument_spec

      def run_this(args, opts)
        if project_required? && Cult.project.nil?
          fail CLIError, "command '#{name}' requires a Cult project"
        end

        check_argument_spec!(args, argument_spec) if argument_spec

        super
      end

      def check_argument_spec!(args, range)
        range = (range..range) if range.is_a?(Integer)
        if range.end == -1
          range = range.begin .. Float::INFINITY
        end

        unless range.cover?(args.size)
          msg = case
            when range.size == 1 && range.begin == 0
              "accepts no arguments"
            when range.size == 1 && range.begin == 1
              "accepts one argument"
            when range.begin == range.end
              "accepts exactly #{range.begin} arguments"
            else
              if range.end == Float::INFINITY
                "requires #{range.begin}+ arguments"
              else
                "accepts #{range} arguments"
              end
          end
          fail CLIError, "Command #{msg}"
        end
      end

      Cri::Command.prepend(self)
    end

    module CommandDSLExtensions
      def optional_project
        @command.project_required = false
      end

      def arguments(range)
        @command.argument_spec = range
      end

      Cri::CommandDSL.prepend(self)
    end
  end
end
