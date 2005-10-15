require 'io/wait'
require 'socket'
require 'thread'

module Stomp

  # Low level connection which maps commands and supports
  # synchronous receives
  class Connection

    def Connection.open(login = "", passcode = "", host='localhost', port=61613)
      Connection.new login, passcode, host, port
    end

    # Create a connection, requires a login and passcode.
    # Can accept a host (default is localhost), and port
    # (default is 61613) to connect to
    def initialize(login, passcode, host='localhost', port=61613)
      @transmit_semaphore = Mutex.new
      @read_semaphore = Mutex.new

      @socket = TCPSocket.open host, port
      transmit "CONNECT", {:login => login, :passcode => passcode}
      @started = true
      @connect = receive()
    end

    # Is this connection open?
    def open?
      !@socket.closed?
    end

    # Is this connection closed?
    def closed?
      !open?
    end

    # Begin a transaction, requires a name for the transaction
    def begin name, headers={}
      headers[:transaction] = name
      transmit "BEGIN", headers
    end

    # Acknowledge a message, used then a subscription has specified 
    # client acknowledgement ( connection.subscribe "/queue/a", :ack => 'client'g
    #
    # Accepts a transaction header ( :transaction => 'some_transaction_id' )
    def ack message_id, headers={}
      headers['message-id'] = message_id
      transmit "ACK", headers
    end
    
    # Commit a transaction by name
    def commit name, headers={}
      headers[:transaction] = name
      transmit "COMMIT", headers
    end

    # Abort a transaction by name
    def abort name, headers={}
      headers[:transaction] = name
      transmit "ABORT", headers
    end

    # Subscribe to a destination, must specify a name
    def subscribe(name, headers = {})
      headers[:destination] = name
      transmit "SUBSCRIBE", headers
    end

    # Unsubscribe from a destination, must specify a name
    def unsubscribe(name, headers = {})
      headers[:destination] = name
      transmit "UNSUBSCRIBE", headers
    end

    # Send message to destination
    #
    # Accepts a transaction header ( :transaction => 'some_transaction_id' )
    def send(destination, message, headers={})
      headers[:destination] = destination
      transmit "SEND", headers, message
    end

    # Close this connection
    def disconnect(headers = {})
      transmit "DISCONNECT", headers
    end

    # Return a pending message if one is available, otherwise
    # return nil
    def poll
      @read_semaphore.synchronize do
        return nil unless @socket.ready?
        return receive
      end
    end
    
    # Receive a frame, block until the frame is received
    def receive
      line = ' '
      @read_semaphore.synchronize do
        line = @socket.gets.chomp while line =~ /\A\s*\Z/ 
        Message.new do |m|
          m.command = line.chomp
          m.headers = {}
          until (line = @socket.gets.chomp) == ''
            k = (line.strip[0, line.strip.index(':')]).strip
            v = (line.strip[line.strip.index(':') + 1, line.strip.length]).strip
            m.headers[k] = v
          end
          if (m.headers['content-length'])
            m.body = @socket.read m.headers['content-length'].to_i
            c = @socket.getc
            raise "Invalid content length received" unless c == 0
          else
            m.body = ''
            until (c = @socket.getc) == 0
              m.body << c.chr
            end
          end
        end
      end
    rescue
      raise "Closed!"
    end

    private
    def transmit(command, headers={}, body='')
      @transmit_semaphore.synchronize do
        @socket.puts command
        headers.each {|k,v| @socket.puts "#{k}:#{v}" }
        @socket.puts "content-length: #{body.length}"
        @socket.puts "content-type: text/plain; charset=UTF-8"
        @socket.puts
        @socket.write body
        @socket.write "\0"
      end
    end
  end

  # Container class for frames, misnamed technically
  class Message
    attr_accessor :headers, :body, :command
    def initialize
      yield(self) if block_given?
    end

    def to_s
      "<Stomp::Message headers=#{headers.inspect} body='#{body}' command='#{command}' >"
    end
  end

  # Typical Stomp client class. Uses a listener thread to receive frames
  # from the server, any thread can send.
  #
  # Receives all happen in one thread, so consider not doing much processing
  # in that thread if you have much message volume.
  class Client

    # Accepts a username (default ""), password (default ""), 
    # host (default localhost), and port (default 61613)
    def initialize user="", pass="", host="localhost", port=61613
      @id_mutex = Mutex.new
      @ids = 1
      @connection = Connection.open user, pass, host, port
      @listeners = {}
      @receipt_listeners = {}
      @running = true
      @listener_thread = Thread.start do
        while @running
          message = @connection.receive
          case
          when message.command == 'MESSAGE': 
              if listener = @listeners[message.headers['destination']]
                listener.call(message)
              end
          when message.command == 'RECEIPT':
              if listener = @receipt_listeners[message.headers['receipt-id']]
                listener.call(message)
              end
          end
        end
      end
    end

    # Accepts a username (default ""), password (default ""), 
    # host (default localhost), and port (default 61613)
    def self.open user="", pass="", host="localhost", port=61613
      Client.new user, pass, host, port
    end

    # Begin a transaction by name
    def begin name, headers={}
      @connection.begin name, headers
    end

    # Abort a transaction by name
    def abort name, headers={}
      @connection.abort name, headers
    end

    # Commit a transaction by name
    def commit name, headers={}
      @connection.commit name, headers
    end
    
    # Subscribe to a destination, must be passed a block 
    # which will be used as a callback listener
    #
    # Accepts a transaction header ( :transaction => 'some_transaction_id' )
    def subscribe destination, headers={}
      raise "No listener given" unless block_given?
      @listeners[destination] = lambda {|msg| yield msg}
      @connection.subscribe destination, headers
    end

    # Unsubecribe from a channel
    def unsubscribe name, headers={}
      @connection.unsubscribe name, headers
      @listeners[name] = nil
    end

    # Acknowledge a message, used then a subscription has specified 
    # client acknowledgement ( connection.subscribe "/queue/a", :ack => 'client'g
    #
    # Accepts a transaction header ( :transaction => 'some_transaction_id' )
    def acknowledge message, headers={}
      if block_given?
        headers['receipt'] = register_receipt_listener lambda {|r| yield r}
      end
      @connection.ack message.headers['message-id'], headers
    end

    # Send message to destination
    #
    # If a block is given a receipt will be requested and passed to the 
    # block on receipt
    #
    # Accepts a transaction header ( :transaction => 'some_transaction_id' )
    def send destination, message, headers = {}
      if block_given?
        headers['receipt'] = register_receipt_listener lambda {|r| yield r}
      end
      @connection.send destination, message, headers
    end

    # Is this client open?
    def open?
      @connection.open?
    end
    
    # Close out resources in use by this client
    def close
      @connection.disconnect
      @running = false 
    end

    private
    def register_receipt_listener listener
      id = -1
      @id_mutex.synchronize do
        id = @ids.to_s
        @ids = @ids.succ
      end
      @receipt_listeners[id] = listener
      id
    end
  end
end
