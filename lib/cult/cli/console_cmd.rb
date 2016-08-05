module Cult
  module CLI

    module_function
    def console_cmd
      Cri::Command.define do
        name        'console'
        summary     'Launch an REPL with you project loaded'
        description <<~EOD
          The Cult console loads your project, and starts a Ruby REPL.  This can
          be useful for troubleshooting, or just poking around the project.

          A few convenience global variables are set to inspect.
        EOD

        flag :i, :irb,  'IRB (default)'
        flag :r, :ripl, 'Ripl'
        flag :p, :pry,  'Pry'

        run do |opts, args|
          globals = {
            p: { value: Cult.project },
            r: { value: Cult.project&.roles&.to_a, caption: "Roles" },
            n: { value: Cult.project&.nodes&.to_a, caption: "Nodes" },
            P: { value: nil, caption: "Provider" }
          }

          globals.each do |k, v|
            caption = if v[:value]
              v[:caption] || v[:value]
            else
              "#{nil.inspect} (#{v[:caption]})"
            end

            # Fuck.
            eval("$#{k} = v[:value]")
            $stderr.puts "$#{k} = #{caption}"
          end

          if opts[:ripl]
            require 'ripl'
            ARGV.clear
            Ripl.start(binding: TOPLEVEL_BINDING)
          elsif opts[:pry]
            require 'pry'
            TOPLEVEL_BINDING.pry
          else
            require 'irb'
            ARGV.clear
            IRB.start
          end
        end
      end
    end

  end
end
