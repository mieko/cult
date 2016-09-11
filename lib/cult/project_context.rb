require 'forwardable'

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

  end
end
