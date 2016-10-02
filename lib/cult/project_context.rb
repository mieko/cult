require 'forwardable'
require 'etc'
require 'socket'

module Cult
  class ProjectContext
    extend Forwardable
    def_delegators :project, :methods, :respond_to?, :to_s, :inspect

    attr_reader :project

    def initialize(project, **extra)
      @project = project

      extra.each do |k, v|
        define_singleton_method(k) { v }
      end
    end

    def method_missing(*args)
      project.send(*args)
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

  end
end
