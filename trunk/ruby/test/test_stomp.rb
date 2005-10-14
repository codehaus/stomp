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
    @conn.send "/queue/a", "hello world"
    msg = @conn.receive
    assert_equal "hello world", msg.body
  end

  def test_receipt
    @conn.subscribe "/queue/a", :receipt => "abc"
    msg = @conn.receive
    assert_equal "abc", msg.headers['receipt-id']
  end

  def test_transaction
    @conn.subscribe "/queue/a"
    @conn.begin "tx1"
    @conn.send "/queue/a", "hello world", 'transaction' => "tx1"
    sleep 0.5
    assert_nil @conn.poll
    @conn.commit "tx1"
    assert_not_nil @conn.receive
  end
end
