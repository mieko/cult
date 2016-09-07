module Cult
  module Transaction
    class Log
      attr_reader :steps
      def initialize
        @steps = []
        yield self if block_given?
      end

      def unwind
        begin
          while (step = steps.pop)
            step.call
          end
        rescue Exception => e
          puts "Error raised while rolling back: #{e.inspect}\n#{e.backtrace}"
          retry
        end
      end

      def protect(&block)
        begin
          yield
        rescue Exception
          $stderr.puts "Rolling back actions"
          unwind
          raise
        end
      end

      def rollback(&block)
        steps.push(block)
      end
    end

    def transaction
      Log.new do |list|
        list.protect do
          yield list
        end
      end
    end
  end
end
