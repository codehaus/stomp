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

class TestStomp < Test::Unit::TestCase

  def setup
    @conn = Stomp::Connection.open "test", "user", "localhost", 61613
  end

  def teardown
    @conn.disconnect
  end

  def make_destination
    "/queue/test/ruby/stomp/" + name()
  end
  
  def test_connection_exists
    assert_not_nil @conn
  end

  def test_explicit_receive
    @conn.subscribe make_destination
    @conn.send make_destination, "test_stomp#test_explicit_receive"
    msg = @conn.receive
    assert_equal "test_stomp#test_explicit_receive", msg.body
  end

  def test_receipt
    @conn.subscribe make_destination, :receipt => "abc"
    msg = @conn.receive
    assert_equal "abc", msg.headers['receipt-id']
  end

  def test_transaction
    @conn.subscribe make_destination
    @conn.begin "tx1"
    @conn.send make_destination, "test_stomp#test_transaction", 'transaction' => "tx1"
    sleep 0.01
    assert_nil @conn.poll
    @conn.commit "tx1"
    assert_not_nil @conn.receive
  end

  def test_client_ack_with_symbol
    @conn.subscribe make_destination, :ack => :client
    @conn.send make_destination, "test_stomp#test_client_ack_with_symbol"
    msg = @conn.receive
    @conn.ack msg.headers['message-id']
  end

  def test_embedded_null
    @conn.subscribe make_destination
    @conn.send make_destination, "a\0"
    msg = @conn.receive
    assert_equal "a\0" , msg.body
  end
end
