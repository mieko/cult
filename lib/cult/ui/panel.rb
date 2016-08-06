require 'shellwords'

require 'cult/role'
require 'cult/node'
require 'cult/ui/tmux'

module Cult
  module UI

    class NodeView
      def initialize(list)
        @list = list
        @list.puts '%set-title Nodes'
        @list.puts '%clear'
        Cult.project.nodes.each do |v|
          @list.puts v.name
        end
        @list.puts '%set-selection 0'
      end

      def node_info(node_name)
        Tmux.replace_pane(0, command: "cult ui role-info #{node_name} | less")
      end

      def process(cmdline)
        case cmdline[0]
          when '%selected-is'
            return if cmdline[2].empty?
            node_info(cmdline[2])
        end
      end
    end

    class RoleView
      def initialize(list)
        @list = list
        @list.puts '%set-title Roles'
        @list.puts '%clear'
        Cult.project.roles.each do |v|
          @list.puts v.name
        end
        @list.puts '%set-selection 0'
      end

      def role_info(name)
        Tmux.replace_pane(0, command: "cult ui role-info #{name} | less -R")
      end

      def process(cmdline)
        case cmdline[0]
          when '%selected-is'
            return if cmdline[2].empty?
            role_info(cmdline[2])
        end
      end
    end

    class Panel
      attr_reader :view

      def initialize
        @list = IO.popen('listpager', 'r+')
        @list.sync = true
        Tmux.resize_pane 1, width: 22

        change_view! NodeView
      end

      def change_view!(cls)
        @view = cls.new(@list)
      end

      def process_line(line)
        cmdline = Shellwords.split(line)
        if cmdline[0] == '%key-pressed' && %w(N n R r).include?(cmdline[1])
          new_cls = (cmdline[1].downcase == 'n') ? NodeView : RoleView
          change_view!(new_cls) unless view.is_a?(new_cls)
          return
        end
        view.process(cmdline)
      end

      def run
        loop do
          while (line = @list.gets)
            process_line(line)
          end
        end
      end
    end

  end
end
