module Cult
  module CLI
    class CLIError < RuntimeError
    end

    class CLIMultipleErrors < CLIError
      attr_reader :errors

      def push(err)
        @errors.push(err)
      end

      def maybe_raise!
        raise self unless errors.empty?
      end

      def collect(auto_raise: true)
        begin
          yield
        rescue CLIError => e
          push(e)
        end
        maybe_raise! if auto_raise
        errors.empty? ? nil : self
      end

      def self.collect(auto_raise: true, &block)
        new.collect(auto_raise: auto_raise, &block)
      end
    end
  end
end
