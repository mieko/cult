require 'erubi'
require 'cult/user_refinements'

module Cult
  class Template
    class Context < ProjectContext
      using ::Cult::UserRefinements

      def initialize(project, pwd: nil, **kwargs)
        @pwd = pwd
        super(project, **kwargs)
      end

      def cultsrcid
        loc = caller_locations(1, 1)[0]
        path = loc.absolute_path

        if path.start_with?(project.path)
          path = project.name + "/" + path[project.path.size + 1..-1]
        end

        user = Etc.getlogin
        host = Socket.gethostname
        vcs = "#{git_branch}@#{git_commit_id(short: true)}"
        timestamp = Time.now.iso8601

        "@cultsrcid: #{path}:#{loc.lineno} #{vcs} #{timestamp} #{user}@#{host}"
      end

      private

      def _process(input, filename: nil)
        Dir.chdir(@pwd || Dir.pwd) do
          erb = Erubi::Engine.new(input, filename: filename)
          binding.eval(erb.src) # rubocop:disable Security/Eval
        end
      end
    end

    attr_reader :context

    def initialize(project:, pwd: nil, **kwargs)
      @context = Context.new(project, pwd: pwd, **kwargs)
    end

    def process(text, filename: nil)
      context.send(:_process, text, filename: filename)
    end
  end
end
