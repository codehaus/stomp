#   Copyright 2005-2006 Brian McCallister
#   Copyright 2006 LogicBlaze Inc.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'io/wait'
require 'socket'
require 'thread'

module Stomp

  # Low level connection which maps commands and supports
  # synchronous receives
  class Connection

    def Connection.open(login = "", passcode = "", host='localhost', port=61613, reliable=FALSE, reconnectDelay=5)
      Connection.new login, passcode, host, port, reliable, reconnectDelay        
    end

    # Create a connection, requires a login and passcode.
    # Can accept a host (default is localhost), and port
    # (default is 61613) to connect to
    def initialize(login, passcode, host='localhost', port=61613, reliable=false, reconnectDelay=5)
      @host = host
      @port = port
      @login = login
      @passcode = passcode
      @transmit_semaphore = Mutex.new
      @read_semaphore = Mutex.new
      @socket_semaphore = Mutex.new
      @reliable = reliable
      @reconnectDelay = reconnectDelay
      @closed = FALSE
      @subscriptions = {}
      @failure = NIL
      socket
    end
  
    def socket
      # Need to look into why the following synchronize does not work.
      #@read_semaphore.synchronize do
        s = @socket;
        while s == NIL or @failure != NIL
          @failure = NIL
          begin
            s = TCPSocket.open @host, @port
            _transmit(s, "CONNECT", {:login => @login, :passcode => @passcode})
            @connect = _receive(s)                        
            # replay any subscriptions.
            @subscriptions.each { |k,v| _transmit(s, "SUBSCRIBE", v) }
          rescue 
            @failure = $!;
            s=NIL;
            raise unless @reliable
            $stderr.print "connect failed: " + $! +" will retry in #{@reconnectDelay}\n";                
            sleep(@reconnectDelay);
          end
        end
        @socket = s
        return s;
      #end
    end
  
    # Is this connection open?
    def open?
      !@closed
    end
  
    # Is this connection closed?
    def closed?
      @closed
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
    def subscribe(name, headers = {}, subId=NIL)
      headers[:destination] = name
      transmit "SUBSCRIBE", headers
      
      # Store the sub so that we can replay if we reconnect.
      if @reliable
        subId = name if subId==NIL
        @subscriptions[subId]=headers
      end
    end
  
    # Unsubscribe from a destination, must specify a name
    def unsubscribe(name, headers = {}, subId=NIL)
      headers[:destination] = name
      transmit "UNSUBSCRIBE", headers
      if @reliable
        subId = name if subId==NIL
        @subscriptions.delete(subId)
      end
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
        return nil if @socket==NIL or !@socket.ready?
        return receive
      end
    end
      
    # Receive a frame, block until the frame is received
    def __old_receive
      # The recive my fail so we may need to retry.
      while TRUE
        begin
          s = socket
          return _receive(s)
        rescue 
          @failure = $!;
          raise unless @reliable
          $stderr.print "receive failed: " + $!;
        end
      end
    end
    
    def receive
      super_result = __old_receive()
      if super_result.nil? && @reliable
        $stderr.print "connection.receive returning EOF as nil - resetting connection.\n"
        @socket = nil
        super_result = __old_receive()
      end         
      return super_result
    end

    private
    def _receive( s )
      line = ' '
      @read_semaphore.synchronize do
        line = s.gets while line =~ /^\s*$/
        return NIL if line == NIL
        Message.new do |m|
          m.command = line.chomp
          m.headers = {}
          until (line = s.gets.chomp) == ''
            k = (line.strip[0, line.strip.index(':')]).strip
            v = (line.strip[line.strip.index(':') + 1, line.strip.length]).strip
            m.headers[k] = v
          end
          
          if (m.headers['content-length'])
            m.body = s.read m.headers['content-length'].to_i
            c = s.getc
            raise "Invalid content length received" unless c == 0
          else
            m.body = ''
            until (c = s.getc) == 0
              m.body << c.chr
            end
          end
          #c = s.getc
          #raise "Invalid frame termination received" unless c == 10
        end
      end
    end

    private
    def transmit(command, headers={}, body='')
      # The transmit my fail so we may need to retry.
      while TRUE
        begin
          s = socket
          _transmit(s, command, headers, body)
          return
        rescue
          @failure = $!;
          raise unless @reliable
          $stderr.print "transmit failed: " + $!+"\n";
        end
      end
    end
      
    private
    def _transmit(s, command, headers={}, body='')
      @transmit_semaphore.synchronize do
        s.puts command
        headers.each {|k,v| s.puts "#{k}:#{v}" }
        s.puts "content-length: #{body.length}"
        s.puts "content-type: text/plain; charset=UTF-8"
        s.puts
        s.write body
        s.write "\0"
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
    def initialize user="", pass="", host="localhost", port=61613, reliable=false
      if user =~ /stomp:\/\/(\w+):(\d+)/
        user = ""
        pass = ""
        host = $1
        port = $2
        reliable = false
      elsif user =~ /stomp:\/\/(\w+):(\w+)@(\w+):(\d+)/
        user = $1
        pass = $2
        host = $3
        port = $4
        reliable = false
      end
      
      @id_mutex = Mutex.new
      @ids = 1
      @connection = Connection.open user, pass, host, port, reliable
      @listeners = {}
      @receipt_listeners = {}
      @running = true
      @replay_messages_by_txn = Hash.new
      @listener_thread = Thread.start do
        while @running
          message = @connection.receive
          case
          when message == NIL:
            break
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
    
    # Join the listener thread for this client,
    # generally used to wait for a quit signal
    def join
      @listener_thread.join
    end

    # Accepts a username (default ""), password (default ""), 
    # host (default localhost), and port (default 61613)
    def self.open user="", pass="", host="localhost", port=61613, reliable=false
      Client.new user, pass, host, port, reliable
    end

    # Begin a transaction by name
    def begin name, headers={}
      @connection.begin name, headers
    end

    # Abort a transaction by name
    def abort name, headers={}
      @connection.abort name, headers

      # lets replay any ack'd messages in this transaction      
      replay_list = @replay_messages_by_txn[name]
      if replay_list
        replay_list.each do |message| 
          if listener = @listeners[message.headers['destination']]
            listener.call(message)
          end
        end
      end
    end

    # Commit a transaction by name
    def commit name, headers={}
      txn_id = headers[:transaction]
      @replay_messages_by_txn.delete(txn_id)
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
      txn_id = headers[:transaction]
      if txn_id
        # lets keep around messages ack'd in this transaction in case we rollback
        replay_list = @replay_messages_by_txn[txn_id]
        if replay_list == nil
          replay_list = []
          @replay_messages_by_txn[txn_id] = replay_list
        end
        replay_list << message
      end
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
