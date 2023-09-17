require_relative "../test_helper"

# Tests for X::Connection class
class ConnectionTest < Minitest::Test
  def setup
    @connection = X::Connection.new(base_url: "https://api.twitter.com/2/", open_timeout: 10, read_timeout: 10,
      write_timeout: 10)
  end

  def test_that_base_uri_changes_affect_http_client
    @connection.base_uri = "http://api.x.com/2/"

    assert_equal "api.x.com", @connection.http_client.address
    assert_equal 80, @connection.http_client.port
    refute_predicate @connection.http_client, :use_ssl?
  end

  def test_that_other_settings_remain_after_base_uri_change
    @connection.base_uri = "http://api.x.com/2/"

    assert_equal 10, @connection.http_client.open_timeout
    assert_equal 10, @connection.http_client.read_timeout
    assert_equal 10, @connection.http_client.write_timeout
  end
end
