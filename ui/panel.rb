module Cult
  module UI

    class Panel
      def listpager_bin
        @result ||= begin
          File.join(File.dirname(__FILE__), "listpager")
        end
      end

      def initialize
      end

      def run
        @list = IO.popen(listpager_bin,'r+')
        @list.sync = true

        50.times do |i|
          @list.puts "Item #{i}"
        end
        @list.puts "%%"
        @list.puts "select 35"
        puts @list.gets

        while (line = @list.gets)
          begin
            @list.puts "Have another: #{line}"
          rescue Interrupt
            break
          end
        end
      end
    end

  end
end
