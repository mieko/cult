require 'net/ssh'
require 'net/scp'
require 'shellwords'
require 'rainbow'

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

    def send_file(ssh, role, transferable)
      src, dst = transferable.path, transferable.remote_path
      data = StringIO.new(transferable.contents(project, role, node,
                                                pwd: role.path))
      puts "Sending file: #{dst}"

      scp = Net::SCP.new(ssh)
      ssh.exec! "mkdir -p #{esc(File.dirname(dst))}"
      scp.upload!(data, dst)
      ssh.exec!("chmod 0#{transferable.file_mode.to_s(8)} #{esc(dst)}")
    rescue
      $stderr.puts "fail: #{role.inspect}, #{transferable.inspect}"
      raise
    end

    def install!(role)
      role.build_order.each do |r|
        puts "Installing role: #{Rainbow(r.name).blue}"
        connect(user: r.definition['user']) do |ssh|
          (r.artifacts + r.tasks).each do |f|
            send_file(ssh, r, f)
          end

          working_dir = r.remote_path

          r.tasks.each do |t|
            puts "Executing: #{t.remote_path}"
            task_bin = r.relative_path(t.path)
            res = ssh.exec! <<~BASH
              cd #{esc(working_dir)}; \
                if [ ! -f ./#{esc(task_bin)}.success ]; then  \
                  touch ./#{esc(task_bin)}.attempt && \
                  ./#{esc(task_bin)} && \
                  touch ./#{esc(task_bin)}.success ; \
                fi
            BASH
            puts res unless res.empty?
          end
        end
      end
    end

    def bootstrap!
      bootstrap_role = CLI.fetch_item('bootstrap', from: Role)
      install!(bootstrap_role)
    end

    def connect(user:, &block)
      Net::SSH.start(node.host, user) do |ssh|
        yield ssh
      end
    end
  end

end
