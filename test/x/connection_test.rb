require_relative "../test_helper"

module X
  # Tests for X::Connection class
  class ConnectionTest < Minitest::Test
    def setup
      @connection = Connection.new(open_timeout: 10, read_timeout: 10, write_timeout: 10)
    end

    def test_set_invalid_proxy_url
      assert_raises ArgumentError do
        @connection.proxy_uri = "ftp://ftp.example.com"
      end
    end

    def test_that_proxy_url_is_set
      connection = Connection.new(proxy_url: "https://user:pass@proxy.com:42")

      assert_equal "user", connection.proxy_user
      assert_equal "pass", connection.proxy_pass
      assert_equal "proxy.com", connection.proxy_host
      assert_equal 42, connection.proxy_port
    end

    def test_that_proxy_is_set_on_http_client
      connection = Connection.new(proxy_url: "https://user:pass@proxy.com:42")
      http_client = connection.send(:build_http_client)

      assert_predicate http_client, :proxy?
      assert_equal "user", http_client.proxy_user
      assert_equal "pass", http_client.proxy_pass
      assert_equal "proxy.com", http_client.proxy_address
      assert_equal 42, http_client.proxy_port
    end

    def test_that_environment_variable_can_set_proxy
      old_value = ENV.fetch("http_proxy", nil)

      ENV["http_proxy"] = "https://user:pass@proxy.com:42"

      http_client = Connection.new.send(:build_http_client)

      assert_predicate http_client, :proxy?
      assert_equal "user", http_client.proxy_user
      assert_equal "pass", http_client.proxy_pass
      assert_equal "proxy.com", http_client.proxy_address
      assert_equal 42, http_client.proxy_port
    ensure
      ENV["http_proxy"] = old_value
    end
  end
end
