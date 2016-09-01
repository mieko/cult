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
