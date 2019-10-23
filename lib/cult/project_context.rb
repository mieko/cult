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
        if v.respond_to?(:call)
          define_singleton_method(k, &v)
        else
          define_singleton_method(k) { v }
        end
      end
    end

    def method_missing(*args)
      if project.respond_to?(args.first)
        project.send(*args)
      else
        super
      end
    end

    def respond_to_missing?(method_name)
      project.respond_to?(method_name) || super
    end

    public :binding
  end
end
