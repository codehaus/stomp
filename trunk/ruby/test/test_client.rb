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
    sleep 0.1 until received
  end

end
