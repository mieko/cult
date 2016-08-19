require 'socket'

module Cult
  module Drivers
    module Common

      module_function
      # Enter this block once a node has been created.  It makes sure it's
      # destroyed if there's an error later in the procedure.
      def rollback_on_error(id:, &block)
        begin
          yield
        rescue Exception => e
          begin
            destroy!(id: id)
          ensure
            raise e
          end
        end
      end

      # Does back-off retrying.  Defaults to not-exponential.
      # Block must throw :done to signal they are done.
      def backoff_loop(wait = 3, scale = 1.2, &block)
        times = 0
        total_wait = 0.0

        catch :done do
          loop do
            yield times, total_wait
            sleep wait
            times += 1
            total_wait += wait
            wait *= scale
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
            # Initiate the socket connection in the background. If it doesn't fail
            # immediately it will raise an IO::WaitWritable (Errno::EINPROGRESS)
            # indicating the connection is in progress.
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
              rescue
                # An unexpected exception was raised - the connection is no good.
                socket.close
                raise
              end
            else
              # IO.select returns nil when the socket is not ready before timeout
              # seconds have elapsed
              socket.close
              raise Errno::ETIMEDOUT
            end
          end
        end
      end

      # Waits until SSH is available at host.  "available" jsut means
      # "listening"/acceping connections.
      def await_ssh(host)
        backoff_loop do
          begin
            sock = connect_timeout(host, 22, 1)
            throw :done
          rescue Errno::ETIMEDOUT, Errno::ECONNREFUSED
            # Nothing, these are expected
          ensure
            sock.close if sock
          end
        end
      end

    end
  end
end
