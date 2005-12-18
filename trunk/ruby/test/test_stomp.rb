$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'test/unit'
require 'stomp'

class TestStomp < Test::Unit::TestCase

  def setup
    @conn = Stomp::Connection.open "test", "user", "localhost", 61613
  end

  def teardown
    @conn.disconnect
  end

  def test_connection_exists
    assert_not_nil @conn
  end

  def test_explicit_receive
    @conn.subscribe "/queue/a"
    @conn.send "/queue/a", "test_stomp#test_explicit_receive"
    msg = @conn.receive
    assert_equal "test_stomp#test_explicit_receive", msg.body
  end

  def test_receipt
    @conn.subscribe "/queue/a", :receipt => "abc"
    msg = @conn.receive
    assert_equal "abc", msg.headers['receipt-id']
  end

  def test_transaction
    @conn.subscribe "/queue/a"
    @conn.begin "tx1"
    @conn.send "/queue/a", "test_stomp#test_transaction", 'transaction' => "tx1"
    sleep 0.01
    assert_nil @conn.poll
    @conn.commit "tx1"
    assert_not_nil @conn.receive
  end

  def test_client_ack_with_symbol
    @conn.subscribe "/queue/a", :ack => :client
    @conn.send "/queue/a", "test_stomp#test_client_ack_with_symbol"
    msg = @conn.receive
    @conn.ack msg.headers['message-id']
  end

  def test_embedded_null
    @conn.subscribe "/queue/a"
    @conn.send "/queue/a", "a\0"
    msg = @conn.receive
    assert_equal "a\0" , msg.body
  end
end
