module Cult
  class Paramap
    attr_reader :enum
    attr_reader :block

    def initialize(enum, &block)
      @enum, @block = enum, block
    end


    def parallel_max
      case (r = Cult.concurrency)
        when :max
          enum.respond_to?(:size) ? enum.size : 200
        else
          r
      end
    end


    def run(njobs = parallel_max)
      iter = enum.to_enum
      active = []
      finished = false

      loop do
        while active.size != njobs
          begin
            next_value = iter.next
          rescue StopIteration
            finished = true
            break
          end

          pid = fork do
            block.call(next_value)
          end
          active.push(pid)
        end

        if active.empty?
          break if finished
        else
          active.delete(Process.waitpid)
        end
      end
    end
  end

  module_function
  def paramap(enum, &block)
    ::Cult::Paramap.new(enum, &block).run
  end
end
