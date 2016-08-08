require 'net/ssh'
require 'net/scp'
require 'shellwords'

module Cult
  class Commander

    attr_reader :project
    attr_reader :node

    def initialize(project, node)
      @project = project
      @node = node
    end

    def rsync?
      false
    end

  end
end

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
      role.definition['user'] || 'cult'
    end

    def send_file(ssh, role, transferable)
      src, dst = transferable.path, transferable.remote_path
      data = StringIO.new(transferable.contents(project, role, node))
      puts "Sending file: #{dst}"

      scp = Net::SCP.new(ssh)
      ssh.exec! "mkdir -p #{Shellwords.escape(File.dirname(dst))}"
      scp.upload!(data, dst)
      ssh.exec!("chmod 0#{transferable.file_mode.to_s(8)} #{Shellwords.escape(dst)}")
    end

    def install!
      role.build_order.each do |r|
        puts "DOING #{r}"
        connect do |ssh|
          (r.artifacts + r.tasks).each do |f|
            send_file(ssh, r, f)
          end

          esc = ->(s) { Shellwords.escape(s) }
          working_dir = r.remote_path

          r.tasks.each do |t|
            puts "Executing: #{t.remote_path}"
            task_bin = r.relative_path(t.path)
            res = ssh.exec! <<~BASH
              cd #{esc.(working_dir)}; \
                if [ ! -f ./#{esc.(task_bin)}.success ]; then  \
                  touch ./#{esc.(task_bin)}.attempt && \
                  ./#{esc.(task_bin)} && \
                  touch ./#{esc.(task_bin)}.success ; \
                fi
            BASH
            puts res unless res.empty?
          end
        end
      end
    end

    def execute!
      connect do |ssh|
        (role.artifacts + role.tasks).each do |f|
          send_file(ssh, role, f)
        end

        esc = ->(s) { Shellwords.escape(s) }
        working_dir = role.remote_path

        role.tasks.each do |t|
          puts "Executing: #{t.remote_path}"
          task_bin = role.relative_path(t.path)
          r = ssh.exec! <<~BASH
            cd #{esc.(working_dir)}; \
              if [ ! -f ./#{esc.(task_bin)}.success ]; then  \
                touch ./#{esc.(task_bin)}.attempt && \
                ./#{esc.(task_bin)} && \
                touch ./#{esc.(task_bin)}.success ; \
              fi
          BASH
          puts r
        end
      end
    end

    def connect(&block)
      connection = Net::SSH.start(host, user) do |ssh|
        yield ssh
      end
    end
  end

end
