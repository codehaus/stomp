#   Copyright 2005-2006 Brian McCallister
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

$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'timeout'
require 'stomp'

class TestClient < Test::Unit::TestCase

  def setup
    @client = Stomp::Client.new("test", "user", "localhost", 61613)
  end

  def teardown
    @client.close
  end

  def message_text
    "test_client#" + name()
  end
  
  def destination
    "/queue/test/ruby/client/" + name()
  end
  
  def test_subscribe_requires_block
    assert_raise(RuntimeError) do
      @client.subscribe destination
    end
  end

  def test_asynch_subscribe
    received = false
    @client.subscribe(destination) {|msg| received = msg}
    @client.send destination, message_text
    sleep 0.01 until received

    assert_equal message_text, received.body
  end
  
  def test_ack_api_works
    @client.send destination, message_text

    received = nil
    @client.subscribe(destination, :ack => 'client') {|msg| received = msg}
    sleep 0.01 until received
    assert_equal message_text, received.body

    receipt = nil
    @client.acknowledge(received) {|r| receipt = r}
    sleep 0.01 until receipt
    assert_not_nil receipt.headers['receipt-id']
  end

  # BROKEN
  def test_noack
    @client.send destination, message_text

    received = nil
    @client.subscribe(destination, :ack => :client) {|msg| received = msg}
    sleep 0.01 until received
    assert_equal message_text, received.body
    @client.close
    
    # was never acked so should be resent to next client

    @client = Stomp::Client.new "test", "user", "localhost", 61613
    received = nil
    @client.subscribe(destination) {|msg| received = msg}
    sleep 0.01 until received
    
    assert_equal message_text, received.body
  end

  def test_receipts
    receipt = false
    @client.send(destination, message_text) {|r| receipt = r}
    sleep 0.1 until receipt

    message = nil
    @client.subscribe(destination) {|m| message = m}
    sleep 0.1 until message
    assert_equal message_text, message.body
  end

  def test_send_then_sub
    @client.send destination, message_text
    message = nil
    @client.subscribe(destination) {|m| message = m}
    sleep 0.01 until message
    
    assert_equal message_text, message.body
  end

  def test_transactional_send
    @client.begin 'tx1'
    @client.send destination, message_text, :transaction => 'tx1'
    @client.commit 'tx1'

    message = nil
    @client.subscribe(destination) {|m| message = m}
    sleep 0.01 until message
    
    assert_equal message_text, message.body
  end

  def test_transaction_send_then_rollback
    @client.begin 'tx1'
    @client.send destination, "first_message", :transaction => 'tx1'
    @client.abort 'tx1'

    @client.begin 'tx1'
    @client.send destination, "second_message", :transaction => 'tx1'
    @client.commit 'tx1'

    message = nil
    @client.subscribe(destination) {|m| message = m}
    sleep 0.01 until message
    assert_equal "second_message", message.body
  end
  
  def test_transaction_ack_rollback_with_new_client
    @client.send destination, message_text

    @client.begin 'tx1'
    message = nil
    @client.subscribe(destination, :ack => 'client') {|m| message = m}
    sleep 0.01 until message
    assert_equal message_text, message.body
    @client.acknowledge message, :transaction => 'tx1'
    message = nil
    @client.abort 'tx1'
    
    # lets recreate the connection
    teardown
    setup
    @client.subscribe(destination, :ack => 'client') {|m| message = m}
 
    Timeout::timeout(4) do 
      sleep 0.01 until message
    end
    assert_not_nil message    
    assert_equal message_text, message.body

    @client.begin 'tx2'
    @client.acknowledge message, :transaction => 'tx2'
    @client.commit 'tx2'
  end
  
  def test_unsubscribe
    message = nil
    client = Stomp::Client.new("test", "user", "localhost", 61613, true)
    client.subscribe(destination, :ack => 'client') { |m| message = m }
    @client.send destination, message_text
    Timeout::timeout(4) do 
      sleep 0.01 until message
    end
    client.unsubscribe destination # was throwing exception on unsub at one point
    
  end
  
  def test_transaction_with_client_side_redelivery
    @client.send destination, message_text

    @client.begin 'tx1'
    message = nil
    @client.subscribe(destination, :ack => 'client') { |m| message = m }
    
    sleep 0.1 while message == nil
    
    assert_equal message_text, message.body
    @client.acknowledge message, :transaction => 'tx1'
    message = nil
    @client.abort 'tx1'

    sleep 0.1 while message == nil
    
    assert_not_nil message    
    assert_equal message_text, message.body

    @client.begin 'tx2'
    @client.acknowledge message, :transaction => 'tx2'
    @client.commit 'tx2'
  end
end
