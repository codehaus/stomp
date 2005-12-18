$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'stomp'

class TestClient < Test::Unit::TestCase

  def setup
    @client = Stomp::Client.new("test", "user", "localhost", 61626)
  end

  def teardown
    @client.close
  end

  def test_subscribe_requires_block
    assert_raise(RuntimeError) do
      @client.subscribe "/queue/a"
    end
  end

  def test_asynch_subscribe
    received = false
    @client.subscribe("/queue/a") {|msg| received = msg}
    @client.send "/queue/a", "test_client#test_asynch_subscribe"
    sleep 0.01 until received

    assert_equal "test_client#test_asynch_subscribe", received.body
  end
  
  def test_ack_api_works
    @client.send "/queue/a", "test_client#test_ack_api_works"

    received = nil
    @client.subscribe("/queue/a", :ack => 'client') {|msg| received = msg}
    sleep 0.01 until received
    assert_equal "test_client#test_ack_api_works", received.body

    receipt = nil
    @client.acknowledge(received) {|r| receipt = r}
    sleep 0.01 until receipt
    assert_not_nil receipt.headers['receipt-id']
  end

  # BROKEN
  def _test_noack
    @client.send "/queue/a", "test_client#test_noack"

    received = nil
    @client.subscribe("/queue/a", :ack => :client) {|msg| received = msg}
    sleep 0.01 until received
    assert_equal "test_client#test_noack", received.body
    @client.close
    
    # was never acked so should be resent to next client

    @client = Stomp::Client.new "test", "user", "localhost", 61613
    received = nil
    @client.subscribe("/queue/a") {|msg| received = msg}
    sleep 0.01 until received
    
    assert_equal "test_client#test_noack", received.body
  end

  def test_receipts
    receipt = false
    @client.send("/queue/a", "test_client#test_receipts") {|r| receipt = r}
    sleep 0.1 until receipt

    message = nil
    @client.subscribe("/queue/a") {|m| message = m}
    sleep 0.1 until message
    assert_equal "test_client#test_receipts", message.body
  end

  def test_send_then_sub
    @client.send "/queue/a", "test_client#test_send_then_sub"
    message = nil
    @client.subscribe("/queue/a") {|m| message = m}
    sleep 0.01 until message
    
    assert_equal "test_client#test_send_then_sub", message.body
  end

  def test_transactional_send
    @client.begin 'tx1'
    @client.send "/queue/a", "test_client#test_transactional_send", :transaction => 'tx1'
    @client.commit 'tx1'

    message = nil
    @client.subscribe("/queue/a") {|m| message = m}
    sleep 0.01 until message
    
    assert_equal "test_client#test_transactional_send", message.body
  end

  def test_transaction_ack_rollback
    @client.send "/queue/a", "test_client#test_transaction_ack_rollback"

    @client.begin 'tx1'
    message = nil
    @client.subscribe("/queue/a", :ack => 'client') {|m| message = m}
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
