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

      def cultsrcid
        loc = caller_locations(1, 1)[0]
        path = loc.absolute_path
        if path.start_with?(project.path)
          path = project.name + "/" + path[project.path.size + 1 .. -1]
        end

        user, host = Etc.getlogin, Socket.gethostname
        vcs = "#{git_branch}@#{git_commit_id(short: true)}"
        timestamp = Time.now.iso8601

        "@cultsrcid: #{path}:#{loc.lineno} #{vcs} #{timestamp} #{user}@#{host}"
      end

      private
      def _process(input, filename: nil)
        Dir.chdir(@pwd || Dir.pwd) do
          erb = Erubis::Eruby.new(input)
          erb.filename = filename
          erb.result(binding)
        end
      end
    end

    attr_reader :context

    def initialize(project:, pwd: nil, **kw)
      @context = Context.new(project, pwd: pwd, **kw)
    end


    def process(text, filename: nil)
      context.send(:_process, text, filename: filename)
    end

  end
end
