require 'socket'
require 'thread'

module Stomp
  class Connection
    attr_reader :queued_messages

    def Connection.open(login = "", passcode = "", host='localhost', port=61613)
      Connection.new login, passcode, host, port
    end

    def initialize(login, passcode, host='localhost', port=61613)
      @queued_messages = []
      @listeners = {}
      @transmit_semaphore = Mutex.new
      @read_semaphore = Mutex.new
      @async_semaphore = Mutex.new
      @socket = TCPSocket.open host, port
      transmit "CONNECT", {:login => login, :passcode => passcode}
      @started = true
      puts receive()
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
        unless @async
          @asynch_semaphore.synchronize do
            unless @asynch
              @asynch = true
              Thread.new do
                while @started
                  raise "WOMBATS"
                end
              end 
            end
          end
        end
        @asynch = true
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
    
    def receive
      if @asynch
        sleep 10 until (m = @queued_messages.shift) 
        return m
      else
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
    end
    
    private
    def asynch_receive(command)
      return if command =~ /\A\s*\Z/

      m = Message.new do |m|
        m.command = command
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
      @transmit_semaphore.synchronize do
        @socket.puts command
        headers.each {|k,v| @socket.puts "#{k}:#{v}" }
        @socket.puts
        @socket.puts body
        @socket.puts "\000"
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
