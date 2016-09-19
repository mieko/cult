module Cult
  class Paramap
    class MultipleExceptions < RuntimeError
      attr_reader :exceptions

      def initialize(exceptions)
        super "mutiple exceptions raised"
        @exceptions = exceptions
      end
    end

    class Job
      attr_reader :ident, :value, :block
      attr_reader :pid, :pipe

      def initialize(ident, value, block)
        @ident, @value, @block = ident, value, block

        @pipe = IO.pipe
        @pid = fork do
          @pipe[0].close
          begin
            write_response!(:result, block.call(value))
          rescue Exception => e
            write_response!(:exception, e)
          end
        end
        @pipe[1].close
      end

      def fetch_response!
        unless pipe[0].closed?
          obj = Marshal.load(@pipe[0].read)
          instance_variable_set("@#{obj[0]}", obj[1])
          pipe[0].close
        end
      end

      def result
        fetch_response!
        @result
      end

      def exception
        fetch_response!
        @exception
      end

      def write_response!(status, obj)
        begin
          pipe[1].write(Marshal.dump([status, obj]))
        rescue TypeError => e
          # Unmarshallable
          raise unless e.message.match(/_dump_data/)
          pipe[1].write(Marshal.dump([status, nil]))
        end
        pipe[1].close
      end

      def success?
        exception.nil?
      end
    end


    attr_reader :enum, :iter
    attr_reader :block
    attr_reader :job_queue
    attr_reader :exception_strategy
    attr_reader :exceptions
    attr_reader :results
    attr_reader :concurrent

    def initialize(enum, concurrent: nil, exception:, &block)
      @enum = enum
      @iter = @enum.to_enum
      @concurrent = concurrent || max_concurrent
      @exception_strategy = exception
      @block = block
      @exceptions, @results = [], []
      @job_queue = []
    end

    def max_concurrent
      case (r = Cult.concurrency)
        when :max
          enum.respond_to?(:size) ? enum.size : 200
        else
          r
      end
    end

    def handle_exception(job)
      case exception_strategy
        when :raise
          raise job.exception
        when :tag
          results[job.ident] = nil
          exceptions[job.ident] = job.exception
        when :collect
          exceptions.push(job.exception)
        when :ignore
          nil
        when Proc
          exception_strategy.call(job.exception)
      end
    end

    def handle_result(job)
      results[job.ident] = job.result
    end

    def handle_response(job)
      job.success? ? handle_result(job) : handle_exception(job)
    end

    def new_job_index
      (@job_index ||= 0).tap do
        @job_index += 1
      end
    end

    def add_job(value)
      job_queue.push(Job.new(new_job_index, value, block))
    end

    def job_by_pid(pid)
      job_queue.find { |job| job.pid == pid }
    end

    def process_finished_job(job)
      job_queue.delete(job)
      handle_response(job)
    end

    def report_exceptions(results)
      if [:raise, :collect].include?(exception_strategy)
        unless exceptions.empty?
          raise MultipleExceptions.new(self.exceptions)
        end
      end

      self_exceptions = self.exceptions
      results.define_singleton_method(:exceptions) do
        self_exceptions
      end
    end

    def job_queue_full?
      job_queue.size == concurrent
    end

    def more_tasks?
      iter.peek
      true
    rescue StopIteration
      false
    end

    def next_task
      iter.next
    end

    def queue_next_task
      add_job(next_task)
    end

    def wait_for_next_job_to_finish
      if (job = job_by_pid(Process.waitpid))
        process_finished_job(job)
      end
    end

    def run
      loop do
        queue_next_task until job_queue_full? || !more_tasks?
        break if job_queue.empty? && ! more_tasks?
        wait_for_next_job_to_finish
      end

      report_exceptions(self.results)
      self.results
    end
  end

  module_function
  def paramap(enum, exception: :raise, &block)
    ::Cult::Paramap.new(enum, exception: exception, &block).run
  end
end
