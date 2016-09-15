require 'net/ssh'
require 'net/scp'
require 'shellwords'
require 'rainbow'
require 'securerandom'

module Cult
  class Commander
    attr_reader :project
    attr_reader :node

    def initialize(project:, node:)
      @project = project
      @node = node
    end

    def esc(s)
      Shellwords.escape(s)
    end


    def send_tar(io, ssh)
      filename = SecureRandom.hex + ".tar"
      puts "Uploading bundle: #{filename}"
      scp = Net::SCP.new(ssh)
      scp.upload!(io, filename)
      ssh.exec! "tar -xf #{esc(filename)} && rm #{esc(filename)}"
    end


    def create_build_tar(role)
      io = StringIO.new
      Bundle.new(io) do |bundle|
        puts "Building bundle..."
        role.build_order.each do |r|
          (r.artifacts + r.build_tasks).each do |transferable|
            bundle.add_file(project, r, node, transferable)
          end
        end
      end

      io.rewind
      io
    end


    def exec_remote!(ssh:, role:, task:)
      token = SecureRandom.hex
      task_bin = role.relative_path(task.path)

      puts "Executing: #{task.remote_path}"
      res = ssh.exec! <<~BASH
        cd #{esc(role.remote_path)}; \
        ./#{esc(task_bin)} && \
        echo #{esc(token)}
      BASH

      if res.chomp.end_with?(token)
        res = res.gsub(token, '')
        puts Rainbow(res.gsub(/^/, '    ')).darkgray.italic
        true
      else
        puts Rainbow(res).red
        puts "Failed"
        false
      end
    end


    def install!(role)
      connect(user: role.user) do |ssh|
        io = create_build_tar(role)
        send_tar(io, ssh)

        role.build_order.each do |r|
          puts "Installing role: #{Rainbow(r.name).blue}"
          r.build_tasks.each do |task|
            exec_remote!(ssh: ssh, role: r, task: task)
          end
        end
      end
    end


    def find_sync_tasks(pass:)
      r = []
      node.build_order.each do |role|
        r += role.event_tasks.select do |t|
          t.event == :sync && t.pass == pass
        end
      end
      r
    end


    def create_sync_tar(pass:)
      io = StringIO.new
      Bundle.new(io) do |bundle|
        find_sync_tasks(pass: pass).each do |task|
          bundle.add_file(project, task.role, node, task)
        end
      end

      io.rewind
      io
    end


    def sync!(pass:)
      io = create_sync_tar(pass: pass)
      return if io.eof?

      connect do |ssh|
        send_tar(io, ssh)
        find_sync_tasks(pass: pass).each do |task|
          exec_remote!(ssh: ssh, role: task.role, task: task)
        end
      end
    end


    def bootstrap!
      bootstrap_role = CLI.fetch_item('bootstrap', from: Role)
      install!(bootstrap_role)
    end

    def ping
      connect do |ssh|
        ssh.exec! "uptime"
      end
    rescue
      nil
    end

    def connect(user: nil, &block)
      5.times do |attempt|
        begin
          user ||= node.user
          puts "Connecting with user=#{user}, host=#{node.host}, " +
               "key=#{node.ssh_private_key_file}"
          Net::SSH.start(node.host,
                         user,
                         port: node.ssh_port,
                         user_known_hosts_file: node.ssh_known_hosts_file,
                         timeout: 5,
                         keys_only: true,
                         keys: [node.ssh_private_key_file]) do |ssh|
            return (yield ssh)
          end
        rescue Errno::ECONNREFUSED
          puts "Connection refused.  Retrying"
          sleep attempt * 3
        end
      end
    end
  end

end
