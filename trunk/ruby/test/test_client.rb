$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'stomp/client'

class TestClient < Test::Unit::TestCase

  def setup
    @client = Stomp::Client.new "test", "user", "localhost", 61613
  end

  def teardown
    @client.close
  end

  def test_kinda_works
    assert_not_nil @client
    assert @client.open?
  end

  def test_subscribe_requires_block
    assert_raise(RuntimeError) do
      @client.subscribe "/queue/a"
    end
  end

  def test_asynch_subscribe
    received = false
    @client.subscribe("/queue/a") {|msg| received = msg}
    @client.send "/queue/a", "hello world"
    sleep 0.01 until received
    assert_not_nil received
  end
  
  def test_ack_api_works
    received = false
    @client.subscribe("/queue/a", :ack => 'client') {|msg| received = msg}
    @client.send "/queue/a", "hello world"
    sleep 0.01 until received
    receipt = nil
    @client.acknowledge(received) {|r| receipt = r}
    sleep 0.01 until receipt
    assert_not_nil receipt.headers['receipt-id']
  end

  def test_noack
    received = false
    @client.subscribe("/queue/a", :ack => 'client') {|msg| received = msg}
    @client.send "/queue/a", "hello world"
    sleep 0.01 until received
    @client.close
    
    # was never acked so should be resent to next client

    @client = Stomp::Client.new "test", "user", "localhost", 61613
    received = nil
    @client.subscribe("/queue/a") {|msg| received = msg}
    sleep 0.01 until received
    assert_not_nil received
  end

  def test_receipts
    receipt = false
    @client.subscribe("/queue/a") {|m|}
    @client.send("/queue/a", "hello world") {|r| receipt = r}
    sleep 0.1 until receipt
  end

  def test_send_then_sub
    @client.send "/queue/a", "hello world"
    message = nil
    @client.subscribe("/queue/a") {|m| message = m}
    sleep 0.01 until message
    assert_not_nil message
  end

  def test_transactional_send
    @client.begin 'tx1'
    @client.send "/queue/a", "hello world", :transaction => 'tx1'
    @client.commit 'tx1'

    message = nil
    @client.subscribe("/queue/a") {|m| message = m}
    sleep 0.01 until message
    assert_not_nil message
  end

  def test_transaction_ack_rollback
    @client.send "/queue/a", "hello world"

    @client.begin 'tx1'
    message = nil
    @client.subscribe("/queue/a", :ack => 'client') {|m| message = m}
    sleep 0.01 until message
    @client.acknowledge message, :transaction => 'tx1'
    @client.abort 'tx1'

    @client.subscribe("/queue/a", :ack => 'client') {|m| message = m}
    sleep 0.01 until message
    assert_equal "hello world", message.body

    @client.begin 'tx2'
    @client.acknowledge message, :transaction => 'tx2'
    @client.commit 'tx2'
  end
end
