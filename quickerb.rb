require 'erb'
require 'shellwords'

module Cult
  class QuickErb
    class Context
      def initialize(**kw)
        kw.each do |k,v|
          define_singleton_method(k) { v }
        end
      end

      def esc(s)
        Shellwords.escape(s)
      end

      def _process(template)
        ::ERB.new(template).result(binding)
      end
    end

    def initialize(**kw)
      @context = Context.new(kw)
    end

    def process(text)
      @context._process(text)
    end
  end
end
