require 'forwardable'
require 'etc'
require 'socket'

module Cult
  # Project Context is a binding useful for "cult console" and templates.  It
  # makes it so "nodes" and "roles" return something useful.

  class ProjectContext
    extend Forwardable
    def_delegators :project, :methods, :respond_to?, :to_s, :inspect

    attr_reader :project

    def initialize(project, **extra)
      @project = project
      extra.each do |k, v|
        v.respond_to?(:call) ? define_singleton_method(k, &v)
                             : define_singleton_method(k) { v }
      end
    end

    def method_missing(*args)
      project.send(*args)
    end

    public :binding
  end
end
