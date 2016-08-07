require 'shellwords'

require 'cult/role'
require 'cult/node'
require 'cult/ui/tmux'

module Cult
  module UI

    class InfoListView
      def title
        'INFOVIEW'
      end

      def collection
        raise NotImplementedError
      end

      def text_for(item)
        item.name
      end

      def on_selection_changed(name)
        Tmux.replace_pane(0, command: "cult ui role-info #{name} | less -R")
      end

      def process(cmdline)
        case cmdline[0]
          when '%selected-is'
            return if cmdline[2].empty?
            on_selection_changed(cmdline[2])
        end
      end

      def initialize(list)
        @list = list
        @list.puts "%set-title #{title}"
        @list.puts '%clear'

        collection.each do |b|
          @list.puts text_for(b)
        end

        @list.puts '%get-selected'
      end
    end

    class NodeView < InfoListView
      def title
        'Nodes'
      end

      def collection
        Cult.project.nodes
      end
    end

    class RoleView < InfoListView
      def title
        'Roles'
      end

      def collection
        Cult.project.roles
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
