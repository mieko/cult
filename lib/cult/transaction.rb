module Cult
  module Transaction
    class Log
      attr_reader :steps
      def initialize
        @steps = []
        yield self if block_given?
      end

      def unwind
        # We stop rolling back when we read entries created in our parent
        # process
        until steps.empty?
          pid, step = steps.last
          break if pid != Process.pid

          steps.pop
          step.call
        end
      rescue Exception => e # rubocop:disable Lint/RescueException
        warn "Execption raised while rolling back: #{e.inspect}\n" + e.backtrace
        retry
      end

      def protect(&_block)
        yield
      rescue Exception => e # rubocop:disable Lint/RescueException
        warn "Rolling back actions due to: #{e.inspect}\n#{e.backtrace}"
        unwind
        raise
      end

      def rollback(&block)
        steps.push([Process.pid, block])
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
