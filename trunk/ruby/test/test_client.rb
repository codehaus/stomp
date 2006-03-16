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
require 'stomp'

class TestClient < Test::Unit::TestCase

  def setup
    @client = Stomp::Client.new("test", "user", "localhost", 61613)
  end

  def teardown
    @client.close
  end

  def make_destination
    "/queue/test/ruby/client/" + name()
  end
  
  def test_subscribe_requires_block
    assert_raise(RuntimeError) do
      @client.subscribe make_destination
    end
  end

  def test_asynch_subscribe
    received = false
    @client.subscribe(make_destination) {|msg| received = msg}
    @client.send make_destination, "test_client#test_asynch_subscribe"
    sleep 0.01 until received

    assert_equal "test_client#test_asynch_subscribe", received.body
  end
  
  def test_ack_api_works
    @client.send make_destination, "test_client#test_ack_api_works"

    received = nil
    @client.subscribe(make_destination, :ack => 'client') {|msg| received = msg}
    sleep 0.01 until received
    assert_equal "test_client#test_ack_api_works", received.body

    receipt = nil
    @client.acknowledge(received) {|r| receipt = r}
    sleep 0.01 until receipt
    assert_not_nil receipt.headers['receipt-id']
  end

  # BROKEN
  def _test_noack
    @client.send make_destination, "test_client#test_noack"

    received = nil
    @client.subscribe(make_destination, :ack => :client) {|msg| received = msg}
    sleep 0.01 until received
    assert_equal "test_client#test_noack", received.body
    @client.close
    
    # was never acked so should be resent to next client

    @client = Stomp::Client.new "test", "user", "localhost", 61613
    received = nil
    @client.subscribe(make_destination) {|msg| received = msg}
    sleep 0.01 until received
    
    assert_equal "test_client#test_noack", received.body
  end

  def test_receipts
    receipt = false
    @client.send(make_destination, "test_client#test_receipts") {|r| receipt = r}
    sleep 0.1 until receipt

    message = nil
    @client.subscribe(make_destination) {|m| message = m}
    sleep 0.1 until message
    assert_equal "test_client#test_receipts", message.body
  end

  def test_send_then_sub
    @client.send make_destination, "test_client#test_send_then_sub"
    message = nil
    @client.subscribe(make_destination) {|m| message = m}
    sleep 0.01 until message
    
    assert_equal "test_client#test_send_then_sub", message.body
  end

  def test_transactional_send
    @client.begin 'tx1'
    @client.send make_destination, "test_client#test_transactional_send", :transaction => 'tx1'
    @client.commit 'tx1'

    message = nil
    @client.subscribe(make_destination) {|m| message = m}
    sleep 0.01 until message
    
    assert_equal "test_client#test_transactional_send", message.body
  end

  # BROKEN
  def _test_transaction_ack_rollback
    @client.send make_destination, "test_client#test_transaction_ack_rollback"

    @client.begin 'tx1'
    message = nil
    @client.subscribe(make_destination, :ack => 'client') {|m| message = m}
    sleep 0.01 until message
    assert_equal "test_client#test_transaction_ack_rollback", message.body
    @client.acknowledge message, :transaction => 'tx1'
    message = nil
    @client.abort 'tx1'

    sleep 0.01 until message
    assert_equal "test_client#test_transaction_ack", message.body

    @client.begin 'tx2'
    @client.acknowledge message, :transaction => 'tx2'
    @client.commit 'tx2'
  end
end
