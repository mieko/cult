require 'erubis'
require 'cult/user_refinements'

module Cult
  class Template
    class Context < ProjectContext
      using ::Cult::UserRefinements

      def initialize(project, pwd: nil, **kw)
        @pwd = pwd
        super(project, **kw)
      end

      def _process(input, filename: nil)
        Dir.chdir(@pwd || Dir.pwd) do
          erb = Erubis::Eruby.new(input)
          erb.filename = filename
          erb.result(binding)
        end
      end

      def binding
        super
      end
    end

    attr_reader :context

    def initialize(project:, pwd: nil, **kw)
      @context = Context.new(project, pwd: pwd, **kw)
    end


    def process(text, filename: nil)
      context._process(text, filename: filename)
    end

  end
end
