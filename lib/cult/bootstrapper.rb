require 'net/ssh'

module Cult
  class Bootstrapper
    attr_reader :project
    attr_reader :node
    attr_reader :role

    def initialize(project:, node:, role: nil)
      @project = project
      @node = node
      @role = role || project.roles.find { |r| r.name == 'bootstrap' }
    end

    def host
      node.host
    end

    def user
      role.json['user'] || 'root'
    end

    def execute!
      connect do |ssh|
        output = ssh.exec!("hostname")
        puts output
      end
    end

    def connect(&block)
      connection = Net::SSH.start(host, user) do |ssh|
        yield ssh
      end
    end
  end

end
