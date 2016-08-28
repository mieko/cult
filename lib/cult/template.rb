require 'erb'
require 'json'

module Cult
  class Template

    # Alright!  We found a use for refinements!
    module Refinements
      module Util
        module_function
        def squote(s)
          "'" + s.gsub("'", "\\\\\'") + "'"
        end


        def quote(s)
          s.to_json
        end


        def slash(s)
          Shellwords.escape(s)
        end
      end

      refine String do
        def quote
          Util.quote(self)
        end
        alias_method :q, :quote


        def squote
          Util.squote(self)
        end
        alias_method :sq, :squote


        def slash
          Util.slash(self)
        end
      end

      refine Array do
        def quote(sep = ' ')
          map {|v| Util.quote(v) }.join(sep)
        end
        alias_method :q, :quote


        def squote(sep = ' ')
          map {|v| Util.squote(v) }.join(sep)
        end
        alias_method :sq, :squote


        def slash
          map {|v| Util.slash(v) }.join(' ')
        end
      end
    end

    class Context
      using Refinements

      def initialize(pwd: nil, **kw)
        @pwd = pwd
        kw.each do |k,v|
          define_singleton_method(k) { v }
        end
      end


      def _process(template)
        Dir.chdir(@pwd || Dir.pwd) do
          ::ERB.new(template).result(binding)
        end
      end
    end


    def initialize(pwd: nil, **kw)
      @context = Context.new(pwd: pwd, **kw)
    end


    def process(text)
      @context._process(text)
    end

  end
end
