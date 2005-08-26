require 'socket'

module Stomp
  class Connection

    def Connection.open(login, passcode, host='localhost', port=61613)
      Connection.new login, passcode, host, port
    end

    def initialize(login, passcode, host='localhost', port=61613)
      @listeners = {}
      @socket = TCPSocket.open host, port
      transmit "CONNECT", {:login => login, :passcode => passcode}
      @started = true
      Thread.new do
        while @started
          receive @socket.gets.chomp
        end
      end
    end

    def begin headers={}
      transmit "BEGIN", headers
    end

    def commit headers={}
      transmit "COMMIT", headers
    end

    def abort headers={}
      transmit "ABORT", headers
    end

    def subscribe(name, headers = {})
      if block_given?
        @listeners[name] = lambda {|m| yield m}
      end
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
      @started = false
      transmit "DISCONNECT", headers
    end

    def on_receipt
      @receipt_listener = lambda { |msg| yield msg }
    end
    
    private
    def receive(command)
      return if command =~ /\A\s*\Z/

      m = Message.new do |m|
        m.command = command
        m.headers = {}
        until (line = @socket.gets.chomp) == ''
          k,v = line.split ":"
          m.headers[k] = v
        end
        m.body = ''
        until (c = @socket.getc) == 0
          m.body << c.chr
        end
      end
      
      case
        when m.command == 'MESSAGE': 
          if listener = @listeners[m.headers['destination']]
            listener.call(m)
          end
        when m.command == 'RECEIPT':
          @receipt_listener.call(m) if @receipt_listener
      end
    end

    def transmit(command, headers={}, body='')
      @socket.puts command
      headers.each {|k,v| @socket.puts "#{k}:#{v}" }
      @socket.puts
      @socket.puts body
      @socket.puts "\000"
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
