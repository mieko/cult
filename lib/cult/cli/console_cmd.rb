require 'delegate'
require 'rainbow'

module Cult
  module CLI

    class ConsoleContext < SimpleDelegator
      attr_accessor :original_argv


      def initialize(project, argv)
        super(project)

        @original_argv = [$0, *argv]
        ENV['CULT_PROJECT'] = self.path
      end


      def load_rc
        consolerc = project.location_of(".cultconsolerc")

        # We don't `load' so the rc file has a more convenient context.
        eval File.read(consolerc) if File.exist?(consolerc)
      end


      private def exit(*)
        # IRB tries to alias this. And it must be private, or it warns.  WTF.
        super
      end


      # Gives us an escape hatch to get the real, non-decorated object
      def project
        __getobj__
      end


      def cult(*argv)
        system $0, *argv
      end


      def binding
        super
      end
    end

    module_function
    def console_cmd
      Cri::Command.define do
        name        'console'
        summary     'Launch an REPL with you project loaded'
        description <<~EOD.format_description
          The Cult console loads your project, and starts a Ruby REPL.  This can
          be useful for troubleshooting, or just poking around the project.

          A few convenience global variables are set to inspect.
        EOD

        flag :i,  :irb,    'IRB (default)'
        flag :r,  :ripl,   'Ripl'
        flag :p,  :pry,    'Pry'
        flag nil, :reexec, 'Console has been exec\'d for a reload'

        run(arguments: 0) do |opts, args, cmd|
          context = ConsoleContext.new(Cult.project, ARGV)

          if opts[:reexec]
            $stderr.puts "Reloaded."
          else
            $stderr.puts <<~EOD

              Welcome to the #{Rainbow('Cult').green} Console.

              Your project has been made accessible via 'project', and forwards
              via 'self':

                => #{context.inspect}

              Useful methods: nodes, roles, providers

            EOD
          end

          context.load_rc

          if opts[:ripl]
            require 'ripl'
            ARGV.clear
            # Look, something reasonable:
            Ripl.start(binding: context.binding)

          elsif opts[:pry]
            require 'pry'
            context.binding.pry
          else
            # irb: This is ridiculous.
            require 'irb'
            ARGV.clear
            IRB.setup(nil)

            irb = IRB::Irb.new(IRB::WorkSpace.new(context.binding))
            IRB.conf[:MAIN_CONTEXT] = irb.context
            IRB.conf[:IRB_RC].call(irb.context) if IRB.conf[:IRB_RC]

            trap("SIGINT") do
              irb.signal_handle
            end

            begin
              catch(:IRB_EXIT) do
                irb.eval_input
              end
            ensure
              IRB::irb_at_exit
            end
          end
        end
      end
    end

  end
end
