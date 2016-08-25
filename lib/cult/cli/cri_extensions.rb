require 'cri'

module Cult
  module CLI
    class ::String
      def format_description
        self.gsub(/(\S)\n(\S)/m, '\1 \2')
            .gsub(/\.[ ]{2}(\S)/m, '. \1')
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

      # This function returns a wrapped version of the block passed to `run`
      def block
        lambda do |opts, args, cmd|
          if project_required? && Cult.project.nil?
            fail CLIError, "command '#{name}' requires a Cult project"
          end

          check_argument_spec!(args, argument_spec) if argument_spec

          super.call(opts, args, cmd)
        end
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

      def run(arguments: nil, &block)
        @command.argument_spec = arguments if arguments
        super(&block)
      end

      Cri::CommandDSL.prepend(self)
    end
  end
end
