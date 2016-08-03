module Cult
  module UI
    class NodeInfo
      def initialize(argv)
        @argv = argv
      end

      def run
        puts "NODE INFO SCREEN!!! #{@argv.inspect}"
        $stdin.gets
      end
    end

  end
end
