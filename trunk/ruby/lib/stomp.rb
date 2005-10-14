require 'io/wait'
require 'socket'
require 'thread'

module Stomp
  class Connection

    def Connection.open(login = "", passcode = "", host='localhost', port=61613)
      Connection.new login, passcode, host, port
    end

    def initialize(login, passcode, host='localhost', port=61613)
      @transmit_semaphore = Mutex.new
      @read_semaphore = Mutex.new

      @socket = TCPSocket.open host, port
      transmit "CONNECT", {:login => login, :passcode => passcode}
      @started = true
      @connect = receive()
    end

    def begin name="default-transaction", headers={ :transaction => name }
      transmit "BEGIN", headers
    end

    def commit name="default-transaction", headers={ :transaction => name }
      transmit "COMMIT", headers
    end

    def abort name="default-transaction", headers={ :transaction => name }
      transmit "ABORT", headers
    end

    def subscribe(name, headers = {})
      headers[:destination] = name
      transmit "SUBSCRIBE", headers
    end

    def unsubscribe(name, headers = {})
      headers[:destination] = name
      transmit "UNSUBSCRIBE", headers
    end

    def send(destination, message, headers={})
      headers[:destination] = destination
      transmit "SEND", headers, message
    end

    def disconnect(headers = {})
      transmit "DISCONNECT", headers
    end

    def poll
      @read_semaphore.synchronize do
        return nil unless @socket.ready?
        return receive
      end
    end
    
    def receive
      line = ' '
      message = @read_semaphore.synchronize do
        line = @socket.gets.chomp while line =~ /\A\s*\Z/ 
        Message.new do |m|
          m.command = line.chomp
          m.headers = {}
          until (line = @socket.gets.chomp) == ''
            k = (line.strip[0, line.strip.index(':')]).strip
            v = (line.strip[line.strip.index(':') + 1, line.strip.length]).strip
            m.headers[k] = v
          end
          m.body = ''
          until (c = @socket.getc) == 0
            m.body << c.chr
          end
        end
      end
      return message
    end

    def transmit(command, headers={}, body='')
      @transmit_semaphore.synchronize do
        @socket.puts command
        headers.each {|k,v| @socket.puts "#{k}:#{v}" }
        @socket.puts
        @socket.print body
        @socket.print "\000"
      end
    end
  end

  class Message
    attr_accessor :headers, :body, :command
    def initialize
      yield(self) if block_given?
    end

    def to_s
      "<Stomp::Message headers=#{headers.inspect} body='#{body}' command='#{command}' >"
    end
  end
end
