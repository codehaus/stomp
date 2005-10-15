require 'stomp'
require 'thread'

module Stomp

  class Client

    # 
    def initialize user="", pass="", host="localhost", port=61613
      @id_mutex = Mutex.new
      @ids = 1
      @connection = Connection.open user, pass, host, port
      @listeners = {}
      @receipt_listeners = {}
      @running = true
      Thread.start do
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
    
    # Subscribe to a destination, must be passed a block 
    # which will be used as a callback listener
    def subscribe destination, headers={}
      raise "No listener given" unless block_given?
      @listeners[destination] = lambda {|msg| yield msg}
      @connection.subscribe destination, headers
    end

    def acknowledge message, headers={}
      if block_given?
        headers['receipt'] = register_receipt_listener lambda {|r| yield r}
      end
      @connection.ack message.headers['message-id'], headers
    end

    # if a block is given a receipt will be requested
    # and passed to the block on receipt
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
      @running = false
      @connection.disconnect
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
