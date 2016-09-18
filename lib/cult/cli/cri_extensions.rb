require 'cri'

module Cult
  module CLI
    class ::String
      def format_description
        self
      end
    end

    # This allows further -- options to be passed as literals instead of
    # being stripped.
    #   cult node ssh Something -- some-command -- something
    module ArgumentArrayExtensions
      attr_reader :explicit_tail

      def initialize(raw_arguments)
        @explicit_tail = []

        super_super = Array.instance_method(:initialize).bind(self)
        if (index = raw_arguments.index("--"))
          @explicit_tail = raw_arguments[index + 1 .. -1]
          processed = raw_arguments[0 ... index] + @explicit_tail
          super_super.call(processed)
        else
          super_super.call(raw_arguments)
        end
        @raw_arguments = raw_arguments
      end

      ::Cri::ArgumentArray.prepend(self)
    end

    # This extension stops option processing at the first non-option bare-word.
    # Without it, further arguments that look like options are treated as such.
    # use-case:
    #  cult node ssh SomeNode ls -l
    module OptionParserExtensions
      def run
        peek = @unprocessed_arguments_and_options[0]
        @no_more_options = true if peek && peek[0] != '-'
        super
      end
      ::Cri::OptionParser.prepend(self)
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
        range = (0..range) if range == Float::INFINITY
        range = (range..range) if range.is_a?(Integer)

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

      ::Cri::Command.prepend(self)
    end


    module CommandDSLExtensions
      def optional_project
        @command.project_required = false
      end


      # Lets us say run(arguments: 1 .. unlimited) instead of
      #   run(arguments: 1 .. Float::INFINITY)
      # or just outright:
      #   run(arguments: unlimited)
      def unlimited
        Float::INFINITY
      end

      # Lets us say run(arguments: none)
      def none
        0
      end

      # This allows an explicit number of arguments to be passed to
      # run, and halts with an error otherwise
      def run(arguments: nil, &block)
        @command.argument_spec = arguments if arguments
        super(&block)
      end

      ::Cri::CommandDSL.prepend(self)
    end
  end
end
