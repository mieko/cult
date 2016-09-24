require 'shellwords'

# These are refinements we enable in a user-facing context, e.g., the console
# or template files.

module Cult
  module UserRefinements
    # Alright!  We found a use for refinements!
    module Util
      module_function

      def squote(s)
        "'" + s.gsub("'", "\\\\\'") + "'"
      end

      def dquote(s)
        '"' + s.gsub('"', '\"') + '"'
      end

      def slash(s)
        Shellwords.escape(s)
      end
    end


    refine String do
      def dquote
        Util.dquote(self)
      end
      alias_method :dq, :dquote
      alias_method :q, :dquote

      def squote
        Util.squote(self)
      end
      alias_method :sq, :squote

      def slash
        Util.slash(self)
      end
      alias_method :e, :slash
    end


    refine Array do
      def dquote(sep = ' ')
        map {|v| Util.dquote(v) }.join(sep)
      end
      alias_method :dq, :dquote
      alias_method :q, :dquote

      def squote(sep = ' ')
        map {|v| Util.squote(v) }.join(sep)
      end
      alias_method :sq, :squote

      def slash(sep = ' ')
        map {|v| Util.slash(v) }.join(sep)
      end
      alias_method :e, :slash
    end
  end
end
