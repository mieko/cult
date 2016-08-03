module Cult
  module CLI

    module_function
    def console_cmd
      Cri::Command.define do
        name 'console'
        summary 'Launch an REPL with you project loaded'
        flag :i, :irb,  'IRB (default)'
        flag :r, :ripl, 'Ripl'
        flag :p, :pry,  'Pry'

        run do |opts, args|
          globals = {
            p: [Cult.project],
            r: [Cult.project.roles.to_a, "Roles"]
          }

          globals.each do |k, v|
            value = v[0]
            caption = v[1] ? v[1] : v[0].inspect
            eval("$#{k} = value")
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
