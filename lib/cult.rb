require 'cult/artifact'
require 'cult/bundle'
require 'cult/commander_sync'
require 'cult/commander'
require 'cult/definition'
require 'cult/driver'
require 'cult/named_array'
require 'cult/node'
require 'cult/paramap'
require 'cult/project_context'
require 'cult/project'
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
      defined?(@singletons) ? @singletons : env_flag('CULT_SINGLETONS', true)
    end


    def concurrency=(v)
      unless v.is_a?(Integer) && v > 0
        fail CLI::CLIError, "concurrency must be a positive integer"
      end
      @concurrency = v
    end


    def concurrency
      defined?(@concurrency) ? @concurrency : :max
    end


    def env_flag(s, default = false)
      case (v = ENV[s])
        when /^0|false|no|n$/i
          false
        when /^1|true|yes|y$/i
          true
        when nil
          default
        else
          fail CLI::CLIError, "Invalid value for boolean #{s}: #{v}"
      end
    end
  end
end
