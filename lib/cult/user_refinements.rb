require 'shellwords'
require 'cult/named_array'
# These are refinements we enable in a user-facing context, e.g., the console
# or template files.

module Cult
  module UserRefinements
    module Util
      module_function

      def squote(str)
        "'" + str.gsub("'", "\\\\\'") + "'"
      end

      def dquote(str)
        '"' + str.gsub('"', '\"') + '"'
      end

      def slash(str)
        Shellwords.escape(str)
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

    refine NamedArray do
      def dquote(sep = ' ')
        map { |v| Util.dquote(v.named_array_identifier) }.join(sep)
      end
      alias_method :dq, :dquote
      alias_method :q, :dquote

      def squote(sep = ' ')
        map { |v| Util.squote(v.named_array_identifier) }.join(sep)
      end
      alias_method :sq, :squote

      def slash(sep = ' ')
        map { |v| Util.slash(v.named_array_identifier) }.join(sep)
      end
      alias_method :e, :slash
    end
  end
end
