require "net/http"
require "uri"
require_relative "../../test_helper"

module X
  class ConnectionProxyTest < Minitest::Test
    cover Connection
    cover ConnectionProxy

    def setup
      @connection = Connection.new
    end

    def test_proxy
      @connection.proxy_url = "http://user:pass@example.com:8080"

      assert_equal URI("http://user:pass@example.com:8080"), @connection.proxy_uri
      assert_equal "example.com", @connection.proxy_host
      assert_equal "user", @connection.proxy_user
      assert_equal "pass", @connection.proxy_pass
      assert_equal 8080, @connection.proxy_port
    end

    def test_invalid_proxy_url
      error = assert_raises(ArgumentError) { @connection.proxy_url = "ftp://ftp.twitter.com/" }

      assert_equal "Invalid proxy URL: ftp://ftp.twitter.com/", error.message
    end

    def test_invalid_proxy_url_message_leaves_out_the_user_and_password
      error = assert_raises(ArgumentError) { @connection.proxy_url = "ftp://user:secret@ftp.twitter.com/" }

      assert_equal "Invalid proxy URL: ftp://ftp.twitter.com/", error.message
    end

    def test_unparseable_proxy_url_raises_argument_error_without_the_password
      error = assert_raises(ArgumentError) { @connection.proxy_url = "http://user:se cret@example.com:8080" }

      assert_equal "Invalid proxy URL: http://example.com:8080", error.message
    end

    def test_invalid_proxy_url_keeps_the_proxy
      @connection.proxy_url = "http://example.com:8080"
      assert_raises(ArgumentError) { @connection.proxy_url = "ftp://ftp.twitter.com/" }

      assert_equal ["http://example.com:8080", URI("http://example.com:8080")], [@connection.proxy_url, @connection.proxy_uri]
    end

    def test_proxy_url_can_be_removed
      @connection.proxy_url = "http://user:pass@example.com:8080"
      @connection.proxy_url = nil

      assert_nil @connection.proxy_url
      assert_nil @connection.proxy_uri
      assert_nil @connection.proxy_user
      assert_nil @connection.proxy_pass
    end

    def test_proxy_host_and_port_without_a_proxy
      assert_nil @connection.proxy_host
      assert_nil @connection.proxy_port
    end

    def test_removing_the_proxy_opens_new_connections
      @connection.proxy_url = "http://example.com:8080"
      pool = @connection.instance_variable_get(:@pool)
      cleared = false
      pool.stub(:clear, -> { cleared = true }) { @connection.proxy_url = nil }

      assert cleared
    end

    def test_proxy_user_and_password_are_decoded
      @connection.proxy_url = "http://us%40er:p%40ss%3Aword@example.com:8080"
      http_client = @connection.send(:build_http_client)

      assert_equal ["us@er", "p@ss:word"], [@connection.proxy_user, @connection.proxy_pass]
      assert_equal ["us@er", "p@ss:word"], [http_client.proxy_user, http_client.proxy_pass]
    end

    def test_proxy_user_without_a_password
      @connection.proxy_url = "http://user@example.com:8080"

      assert_equal "user", @connection.proxy_user
      assert_nil @connection.proxy_pass
    end

    def test_inspect_without_a_proxy
      assert_equal "#<X::Connection proxy_url=nil open_timeout=60 read_timeout=60 write_timeout=60>", @connection.inspect
    end

    def test_inspect_hides_the_proxy_user_and_password_of_a_uri
      connection = Connection.new(proxy_url: URI("http://user:secret@example.com:8080"))

      assert_equal "#<X::Connection proxy_url=\"http://example.com:8080\" open_timeout=60 read_timeout=60 write_timeout=60>", connection.inspect
    end

    def test_invalid_proxy_url_message_leaves_out_an_empty_user
      error = assert_raises(ArgumentError) { @connection.proxy_url = "ftp://@ftp.twitter.com/" }

      assert_equal "Invalid proxy URL: ftp://ftp.twitter.com/", error.message
    end

    def test_inspect_hides_the_proxy_user_and_password
      connection = Connection.new(open_timeout: 1, read_timeout: 2, write_timeout: 3, proxy_url: "http://user:secret@example.com:8080")

      assert_equal "#<X::Connection proxy_url=\"http://example.com:8080\" open_timeout=1 read_timeout=2 write_timeout=3>", connection.inspect
    end

    def test_proxy_settings_are_respected_in_http_client
      @connection.proxy_url = "http://user:pass@example.com:8080"
      http_client = @connection.send(:build_http_client)

      assert_equal "example.com", http_client.proxy_address
      assert_equal 8080, http_client.proxy_port
      assert_equal "user", http_client.proxy_user
      assert_equal "pass", http_client.proxy_pass
    end

    def test_set_env_proxy
      old_value = ENV.fetch("http_proxy", nil)
      ENV["http_proxy"] = "https://user:pass@example.com:8080"
      http_client = Connection.new.send(:build_http_client)

      assert_predicate http_client, :proxy?
      assert_equal "user", http_client.proxy_user
      assert_equal "pass", http_client.proxy_pass
      assert_equal "example.com", http_client.proxy_address
      assert_equal 8080, http_client.proxy_port
    ensure
      ENV["http_proxy"] = old_value
    end
  end

  class ConnectionProxyHTTPClientTest < Minitest::Test
    cover Connection
    cover ConnectionProxy

    def test_host_port_with_proxy
      connection = Connection.new(proxy_url: "https://user:pass@example.com")
      http_client = connection.send(:build_http_client, "example.com", 8080)

      assert_predicate http_client, :proxy?
      assert_equal "example.com", http_client.address
      assert_equal 8080, http_client.port
    end

    def test_http_proxy_is_connected_to_without_tls
      http_client = Connection.new(proxy_url: "http://example.com:8080").send(:build_http_client)

      assert_same false, http_client.instance_variable_get(:@proxy_use_ssl)
    end

    def test_https_proxy_is_connected_to_over_tls
      http_client = Connection.new(proxy_url: "https://user:pass@example.com:8443").send(:build_http_client)

      assert_same true, http_client.instance_variable_get(:@proxy_use_ssl)
    end
  end
end
