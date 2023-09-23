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

  def test_that_proxy_url_is_set_on_the_http_client
    connection = X::Connection.new(proxy_url: "https://proxy.com:42")

    assert_predicate connection.http_client, :proxy?
    assert_equal "proxy.com", connection.http_client.proxy_address
    assert_equal 42, connection.http_client.proxy_port
  end

  def test_that_authenticated_proxy_url_is_set_on_the_http_client
    connection = X::Connection.new(proxy_url: "https://user:pass@proxy.com")

    assert_predicate connection.http_client, :proxy?
    assert_equal "user", connection.http_client.proxy_user
    assert_equal "pass", connection.http_client.proxy_pass
  end

  def test_that_environment_variable_can_set_proxy_on_the_http_client
    old_value = ENV.fetch("http_proxy", nil)

    ENV["http_proxy"] = "https://proxy.com:42"

    connection = X::Connection.new

    assert_predicate connection.http_client, :proxy?
    assert_equal "proxy.com", connection.http_client.proxy_address
    assert_equal 42, connection.http_client.proxy_port
  ensure
    ENV["http_proxy"] = old_value
  end
end
