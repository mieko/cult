require 'socket'
require 'net/ssh'

require 'cult/transaction'

module Cult
  module Drivers
    module Common
      module ClassMethods
        # Lets us write a method "something_map" that returns {'ident' => ...},
        # and also get a function "something" that returns the keys.
        def with_id_mapping(method_name)
          new_method = method_name.to_s.sub(/_map\z/, '')
          define_method(new_method) do
            send(method_name).keys
          end
        end

        def memoize(method_name)
          old_method_name = "#{method_name}_unmemoized".to_sym

          alias_method old_method_name, method_name

          var_name = "@#{method_name}".to_sym

          define_method(method_name) do
            unless instance_variable_defined?(var_name)
              instance_variable_set(var_name, send(old_method_name))
            end
            instance_variable_get(var_name)
          end

          define_method("#{method_name}_unmemo!") do
            remove_instance_variable(var_name)
          end
        end
      end

      # works with with_id_mapping to convert a human-readible/normalized key
      # to the id the backend service expects.  Allows '=value' to force a
      # literal value, and gives better error messages.
      def fetch_mapped(name:, from:, key:)
        # Allow for the override.
        key = key.to_s
        return key[1..-1] if key[0] == '='

        begin
          from.fetch(key)
        rescue KeyError
          raise ArgumentError, "Invalid #{name}: \"#{key}\"." \
                               "Use \"=#{key}\" to force, or use one of: #{from.keys.inspect}"
        end
      end

      def ssh_key_info(data: nil, file: nil)
        if data.nil?
          fail ArgumentError if file.nil?

          data = File.read(file)
        else
          fail ArgumentError unless file.nil?
        end

        data = data.chomp
        key = Net::SSH::KeyFactory.load_data_public_key(data, file)

        fields = data.split(/ /)

        {
          name: fields[-1],
          fingerprint: key.fingerprint,
          data: data,
          file: file
        }
      end

      def slugify(str)
        str.gsub(/[^a-z0-9]+/i, '-').gsub(/(^\-)|(-\z)/, '').downcase
      end

      def distro_name(str)
        str = str.gsub(/\bx64\b/i, '')
        # People sometimes add "LTS" to the name of Ubuntu LTS releases
        str = str.gsub(/\blts\b/i, '') if str.match(/ubuntu/i)

        # We don't particularly need the debian codename
        str = str.gsub(/(\d)[\s-]+(\S+)/, '\1') if str.match(/^debian/i)
        str = str.gsub(/[\s.]+/, '-')
        str.downcase
      end

      # Does back-off retrying.  Defaults to non-exponential.
      # Block must throw :done to signal they are done.
      def backoff_loop(wait = 3, scale = 1.2, &_block)
        times = 0
        total_wait = 0.0

        loop do
          yield times, total_wait
          sleep wait
          times += 1
          total_wait += wait
          wait *= scale
        end
      end

      # Waits until SSH is available at host.  "available" jsut means
      # "listening"/acceping connections.
      def await_ssh(host)
        puts "Awaiting sshd on #{host}"
        backoff_loop do
          begin
            sock = connect_timeout(host, 22, 1)
            break
          rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EHOSTDOWN
            # Nothing, these are expected
          ensure
            sock&.close
          end
        end
      end

      # This should not be needed, but it is:
      # https://spin.atomicobject.com/2013/09/30/socket-connection-timeout-ruby/
      def connect_timeout(host, port, timeout = 5)
        # Convert the passed host into structures the non-blocking calls
        # can deal with
        addr = Socket.getaddrinfo(host, nil)
        sockaddr = Socket.pack_sockaddr_in(port, addr[0][3])

        Socket.new(Socket.const_get(addr[0][0]), Socket::SOCK_STREAM, 0).tap do |socket|
          socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

          begin
            # Initiate the socket connection in the background. If it doesn't
            # fail immediately it will raise an IO::WaitWritable
            # (Errno::EINPROGRESS) indicating the connection is in progress.
            socket.connect_nonblock(sockaddr)
          rescue IO::WaitWritable
            # IO.select will block until the socket is writable or the timeout
            # is exceeded - whichever comes first.
            if IO.select(nil, [socket], nil, timeout)
              begin
                # Verify there is now a good connection
                socket.connect_nonblock(sockaddr)
              rescue Errno::EISCONN
                # Good news everybody, the socket is connected!
              rescue StandardError
                # An unexpected exception was raised - the connection is no good.
                socket.close
                raise
              end
            else
              # IO.select returns nil when the socket is not ready before
              # timeout seconds have elapsed
              socket.close
              raise Errno::ETIMEDOUT
            end
          end
        end
      end

      def self.included(cls)
        cls.extend(ClassMethods)
        cls.include(::Cult::Transaction)
      end
    end
  end
end
