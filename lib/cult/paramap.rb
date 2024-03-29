# Cult.paramap runs a block in forked-off parallel processes.  There are very
# little restrictions on what can be done in the block, but:
#
#  1. The value returned or any exceptions raised need to be Marshal-able.
#  2. The blocks actually need to resume execution, so things like `exec`
#     cause problems.
#
# The result of paramap is an array corresponding with each value ran through
# the block.  There are a few exception strategies:
#
# 1. :raise The first job to throw an exception halts all further work and the
#    exception is passed up
# 2. :collect All jobs are allowed to complete, any exceptions encounted are
#    tagged on the results in an `exception` method, which returns an array
#    each element will either be 'nil' for no exception, or the Exception
#    object the job raised.

module Cult
  class Paramap
    class Job
      attr_reader :ident, :value, :rebind, :block
      attr_reader :pid, :pipe

      def initialize(ident, value, rebind: {}, &block)
        @ident = ident
        @value = value
        @rebind = rebind
        @block = block

        @pipe = IO.pipe
        @pid = fork do
          @pipe[0].close
          prepare_forked_environment!
          begin
            write_response!('=', block.call(value))
          rescue Exception => e # rubocop:disable Lint/RescueException
            write_response!('!', e)
          end
        end
        @pipe[1].close
      end

      def rebind_streams!
        names = {
          stdout: STDOUT,
          stdin: STDIN,
          stderr: STDERR,
          nil => '/dev/null'
        }
        rebind.each do |k, v|
          src = names[k]
          dst = names[v]
          dst = File.open(dst, 'w+') if dst.is_a?(String)
          src.reopen(dst)
        end
      end

      def prepare_forked_environment!
        rebind_streams!
        # Stub out things that have caused a problem in the past.
        Kernel.send(:define_method, :exec) do |*_args|
          fail "don't use Kernel\#exec inside of a paramap job"
        end
      end

      def write_response!(scode, obj)
        fail unless ['!', '='].include?(scode)

        begin
          pipe[1].write(scode + Marshal.dump(obj))
        rescue TypeError => e
          # Unmarshallable
          raise unless e.message.match(/_dump_data/)

          pipe[1].write(scode + Marshal.dump(nil))
        end
        pipe[1].flush
        pipe[1].close
      end

      def fetch_response!
        unless pipe[0].closed?
          data = @pipe[0].read

          scode = data[0]
          fail unless ['!', '='].include?(scode)

          data = data[1..-1]
          ivar = scode == '!' ? :exception : :result
          begin
            obj = Marshal.load(data) # rubocop:disable Security/MarshalLoad
          rescue Exception # rubocop:disable Lint/RescueException
            obj = nil
          end
          instance_variable_set("@#{ivar}", obj)
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

      def success?
        exception.nil?
      end
    end

    attr_reader :enum, :iter
    attr_reader :rebind
    attr_reader :block
    attr_reader :job_queue
    attr_reader :exception_strategy
    attr_reader :exceptions
    attr_reader :results
    attr_reader :concurrent

    def initialize(enum, rebind: {}, concurrent: nil, exception_strategy:, &block)
      @enum = enum
      @rebind = rebind
      @iter = @enum.to_enum
      @concurrent = concurrent || max_concurrent
      @exception_strategy = exception_strategy
      @block = block

      @exceptions = []
      @results = []
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
        when :collect
          exceptions.push(job.exception)
        else
          fail "Bad exception_strategy: #{exception_strategy}"
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
      job_queue.push(Job.new(new_job_index, value, rebind: rebind, &block))
    end

    def job_by_pid(pid)
      job_queue.find { |job| job.pid == pid }
    end

    def process_finished_job(job)
      job_queue.delete(job)
      handle_response(job)
    end

    def report_exceptions(results)
      self_exceptions = exceptions
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
        break if job_queue.empty? && !more_tasks?

        wait_for_next_job_to_finish
      end

      report_exceptions(results)
      results
    end
  end
  private_constant :Paramap

  module_function

  def paramap(enum, quiet: false, concurrent: nil, exception: :raise, &block)
    rebind = quiet ? { stdout: nil, stderr: nil } : {}
    Paramap.new(enum,
                rebind: rebind,
                concurrent: concurrent,
                exception_strategy: exception, &block).run
  end
end
