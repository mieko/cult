require 'cult/artifact'
require 'cult/bundle'
require 'cult/commander'
require 'cult/definition'
require 'cult/driver'
require 'cult/named_array'
require 'cult/node'
require 'cult/project'
require 'cult/project_context'
require 'cult/provider'
require 'cult/role'
require 'cult/singleton_instances'
require 'cult/skel'
require 'cult/task'
require 'cult/template'
require 'cult/transaction'
require 'cult/transferable'
require 'cult/version'


module Cult
  class << self
    attr_accessor :project

    attr_writer :singletons
    def singletons?
      @singletons
    end
  end
end
