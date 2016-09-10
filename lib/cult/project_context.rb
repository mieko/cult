require 'cult/project'
require 'forwardable'

module Cult
  class ProjectContext
    attr_reader :project

    def initialize(project, **extra)
      @project = project

      extra.each do |k, v|
        define_singleton_method(k) { v }
      end
    end

    def method_missing(*args)
      puts args.inspect
      project.send(*args)
    end

    def methods
      project.methods
    end

    def respond_to?(*args)
      project.send(__method__, *args)
    end
  end

end
