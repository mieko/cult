module Cult
  class Paramap
    class MultipleExceptions < RuntimeError
      attr_reader :exceptions

      def initialize(*exceptions)
        @exceptions = exceptions
        super("mutiple exceptions raised")
      end
    end

    class Sub
      attr_reader :pid
      attr_reader :ident

      def initialize(ident, value, block)
        @ident = ident
        @pipe = IO.pipe
        @pid = fork do
          @pipe[0].close
          begin
            write_result!(:result, block.call(value))
          rescue Exception => e
            write_result!(:exception, e)
          end
        end
        @pipe[1].close
      end

      def read_result!
        if ! defined?(@finalized)
          @finalized = true
          obj = Marshal.load(@pipe[0].read)
          case obj[0]
            when :result
              @result = obj[1]
            when :exception
              @exception = obj[1]
          end
          @pipe.each(&:close)
        end
      end

      def result
        read_result!
        @result
      end

      def exception
        read_result!
        @exception
      end

      def write_result!(status, obj)
        begin
          @pipe[1].write(Marshal.dump([status, obj]))
        rescue TypeError => e
          if e.message.match(/_dump_data/)
            @pipe[1].write(Marshal.dump([status, nil]))
          else
            raise
          end
        end
        @pipe[1].flush
        @pipe[1].close
      end

      def success?
        read_result!
        @exception.nil?
      end
    end


    attr_reader :enum
    attr_reader :block
    attr_reader :exception_strategy
    attr_reader :exceptions
    attr_reader :results


    def initialize(enum, exception:, &block)
      @enum = enum
      @exception_strategy = exception
      @block = block
      @exceptions = []
      @results = []
    end


    def max_parallel
      case (r = Cult.concurrency)
        when :max
          enum.respond_to?(:size) ? enum.size : 200
        else
          r
      end
    end

    def handle_exception(sub)
      case exception_strategy
        when :raise
          raise sub.exception
        when :tag
          results[sub.ident] = nil
          exceptions[sub.ident] = sub.exception
        when :collect
          exceptions.push(sub.exception)
        when :ignore
          nil
        when Proc
          exception_strategy.call(sub.exception)
      end
    end

    def handle_result(sub)
      results[sub.ident] = sub.result
    end

    def handle_response(sub)
      sub.success? ? handle_result(sub) : handle_exception(sub)
    end

    def run(njobs = max_parallel)
      iter = enum.to_enum
      active = []
      finished = false
      i = 0

      loop do
        while !finished && active.size != njobs
          begin
            next_value = iter.next
          rescue StopIteration
            finished = true
            break
          end
          active.push(Sub.new(i, next_value, block))
          i += 1
        end

        if active.empty?
          break if finished
        else
          pid = Process.waitpid
          if (sub = active.find {|sub| sub.pid == pid})
            active.delete(sub)
            handle_response(sub)
          end
        end
      end

      if [:raise, :collect].include?(exception_strategy)
        unless self.exceptions.empty?
          raise MultipleExceptions.new(*self.exceptions)
        end
      end

      e = self.exceptions
      self.results.define_singleton_method(:exceptions) do
        e
      end
      self.results
    end
  end

  module_function
  def paramap(enum, exception: :raise, &block)
    ::Cult::Paramap.new(enum, exception: exception, &block).run
  end
end
