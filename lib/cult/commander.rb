require 'net/ssh'
require 'net/scp'
require 'shellwords'
require 'rainbow'
require 'rubygems/package'
require 'rubygems/package/tar_writer'

module Cult

  class Bundle
    attr_reader :tar
    def initialize(io, &block)
      @tar = Gem::Package::TarWriter.new(io)
      if block_given?
        begin
          yield self
        ensure
          @tar.close
          @tar = nil
        end
      end
    end

    def add_file(project, role, node, transferable)
      data = transferable.contents(project, role, node, pwd: role.path)
      tar.add_file(transferable.remote_path, transferable.file_mode) do |io|
        io.write(data)
      end
    end
  end

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

    def send_bundle(ssh, role)
      io = StringIO.new
      Bundle.new(io) do |bundle|
        puts "Building bundle..."
        role.build_order.each do |r|
          (r.artifacts + r.tasks).each do |transferable|
            bundle.add_file(project, r, node, transferable)
          end
        end
      end
      filename = "cult-#{role.name}.tar"
      puts "Uploading bundle #{filename}..."

      scp = Net::SCP.new(ssh)
      io.rewind
      scp.upload!(io, filename)
      ssh.exec! "tar xf #{esc(filename)} && rm #{esc(filename)}"
    end

    def install!(role)
      connect(user: role.definition['user']) do |ssh|
        send_bundle(ssh, role)

        role.build_order.each do |r|
          puts "Installing role: #{Rainbow(r.name).blue}"
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
            unless res.empty?
              puts Rainbow(res.gsub(/^/, '    ')).darkgray.italic
            end
          end
        end
      end
    end

    def bootstrap!
      bootstrap_role = CLI.fetch_item('bootstrap', from: Role)
      install!(bootstrap_role)
    end

    def connect(user:, &block)
      puts "Connecting with user=#{user}"
      Net::SSH.start(node.host, user) do |ssh|
        yield ssh
      end
    end
  end

end
