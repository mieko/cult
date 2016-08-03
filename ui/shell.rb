require 'shellwords'
require_relative './panel'

module Cult
  module UI

    class Shell
      def initialize
      end

      def run
        exec tmux_sh, project&.path
      end

      def panel(argv = [])
        Panel.new.run
      end

      def welcome
        doc 'welcome'
      end

      # Just opens a static file in a pager.
      def doc(name)
        file = File.join(File.dirname(__FILE__), "../doc", "#{name}.txt")
        file = File.expand_path(file)
        exec "less -M --tilde --quiet #{esc file}"
      end

      def tmux_sh
        File.join(File.dirname(__FILE__), "tmux.sh")
      end

      def project
        Cult.project
      end

      def esc(v)
        Shellwords.escape(v)
      end
    end

  end
end
