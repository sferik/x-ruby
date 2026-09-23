# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "../../test_helper"

module X
  class ConnectionProxyTest < Minitest::Test
    cover Connection
    cover Core::ConnectionProxy

    def setup
      @connection = Connection.new
    end

    def test_proxy
      connection = Connection.new(proxy_url: "http://user:pass@example.com:8080")
      http_client = connection.send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_equal ["http://user:pass@example.com:8080", URI("http://user:pass@example.com:8080")],
        [connection.send(:proxy_url), connection.send(:proxy_uri)]
      assert_equal ["example.com", 8080, "user", "pass"],
        [http_client.proxy_address, http_client.proxy_port, http_client.proxy_user, http_client.proxy_pass]
    end

    def test_a_connection_reveals_nothing_of_its_proxy
      connection = Connection.new(proxy_url: "http://user:pass@example.com:8080")

      %i[proxy_url proxy_uri proxy_host proxy_port proxy_user proxy_pass].each do |name|
        refute_respond_to connection, name
      end
    end

    def test_neither_a_client_nor_a_streaming_client_reveals_its_proxy
      client = Client.new(proxy_url: "http://user:pass@example.com:8080")

      refute_respond_to client, :proxy_url
      refute_respond_to client.streaming, :proxy_url
    end

    def test_invalid_proxy_url
      error = assert_raises(ArgumentError) { Connection.new(proxy_url: "ftp://ftp.twitter.com/") }

      assert_equal "Invalid proxy URL: ftp://ftp.twitter.com/", error.message
    end

    def test_invalid_proxy_url_message_leaves_out_the_user_and_password
      error = assert_raises(ArgumentError) { Connection.new(proxy_url: "ftp://user:secret@ftp.twitter.com/") }

      assert_equal "Invalid proxy URL: ftp://ftp.twitter.com/", error.message
    end

    def test_unparseable_proxy_url_raises_argument_error_without_the_password
      error = assert_raises(ArgumentError) { Connection.new(proxy_url: "http://user:se cret@example.com:8080") }

      assert_equal "Invalid proxy URL: http://example.com:8080", error.message
    end

    def test_a_connection_built_without_a_proxy_has_none
      assert_equal [nil, nil], [@connection.send(:proxy_url), @connection.send(:proxy_uri)]
    end

    def test_the_proxy_host_is_given_without_the_brackets_of_an_ipv6_literal
      http_client = Connection.new(proxy_url: "http://[::1]:8080").send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_equal "::1", http_client.proxy_address
    end

    def test_proxy_user_and_password_are_decoded
      connection = Connection.new(proxy_url: "http://us%40er:p%40ss%3Aword@example.com:8080")
      http_client = connection.send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_equal ["us@er", "p@ss:word"], [http_client.proxy_user, http_client.proxy_pass]
    end

    def test_proxy_user_without_a_password
      connection = Connection.new(proxy_url: "http://user@example.com:8080")
      http_client = connection.send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_equal ["user", nil], [http_client.proxy_user, http_client.proxy_pass]
    end

    def test_inspect_without_a_proxy
      assert_equal "#<X::Connection proxy_url=nil open_timeout=10 read_timeout=60 write_timeout=60>", @connection.inspect
    end

    def test_inspect_hides_the_proxy_user_and_password_of_a_uri
      connection = Connection.new(proxy_url: URI("http://user:secret@example.com:8080"))

      assert_equal "#<X::Connection proxy_url=\"http://example.com:8080\" open_timeout=10 read_timeout=60 write_timeout=60>", connection.inspect
    end

    def test_invalid_proxy_url_message_leaves_out_an_empty_user
      error = assert_raises(ArgumentError) { Connection.new(proxy_url: "ftp://@ftp.twitter.com/") }

      assert_equal "Invalid proxy URL: ftp://ftp.twitter.com/", error.message
    end

    def test_inspect_hides_the_proxy_user_and_password
      connection = Connection.new(open_timeout: 1, read_timeout: 2, write_timeout: 3, proxy_url: "http://user:secret@example.com:8080")

      assert_equal "#<X::Connection proxy_url=\"http://example.com:8080\" open_timeout=1 read_timeout=2 write_timeout=3>", connection.inspect
    end

    def test_proxy_settings_are_respected_in_http_client
      connection = Connection.new(proxy_url: "http://user:pass@example.com:8080")
      http_client = connection.send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_equal "example.com", http_client.proxy_address
      assert_equal 8080, http_client.proxy_port
      assert_equal "user", http_client.proxy_user
      assert_equal "pass", http_client.proxy_pass
    end
  end

  class ConnectionProxyEnvironmentTest < Minitest::Test
    cover Connection
    cover Core::ConnectionProxy

    def test_https_proxy_of_the_environment_is_used_for_an_https_request
      with_proxy_env(https_proxy: "http://us%40er:p%40ss@example.com:8080") do
        http_client = Connection.new.send(:build_http_client, URI("https://api.x.com/2/tweets"))

        assert_predicate http_client, :proxy?
        assert_equal ["example.com", 8080, "us@er", "p@ss"],
          [http_client.proxy_address, http_client.proxy_port, http_client.proxy_user, http_client.proxy_pass]
      end
    end

    def test_http_proxy_of_the_environment_is_used_for_an_http_request
      with_proxy_env(http_proxy: "http://example.com:8080") do
        assert_predicate Connection.new.send(:build_http_client, URI("http://api.x.com/2/tweets")), :proxy?
      end
    end

    def test_http_proxy_of_the_environment_is_not_used_for_an_https_request
      with_proxy_env(http_proxy: "http://example.com:8080") do
        refute_predicate Connection.new.send(:build_http_client, URI("https://api.x.com/2/tweets")), :proxy?
      end
    end

    def test_no_proxy_of_the_environment_reaches_the_host_directly
      with_proxy_env(https_proxy: "http://example.com:8080", no_proxy: "api.x.com") do
        refute_predicate Connection.new.send(:build_http_client, URI("https://api.x.com/2/tweets")), :proxy?
      end
    end

    def test_the_proxy_url_of_a_connection_is_used_rather_than_the_environment
      with_proxy_env(https_proxy: "http://environment.example.com:8080") do
        http_client = Connection.new(proxy_url: "http://given.example.com:3128").send(:build_http_client, URI("https://api.x.com/2/tweets"))

        assert_equal "given.example.com", http_client.proxy_address
      end
    end

    private

    # Run a block with the proxy variables of the environment set to the values given, and the rest of them cleared
    def with_proxy_env(http_proxy: nil, https_proxy: nil, no_proxy: nil)
      values = {"http_proxy" => http_proxy, "https_proxy" => https_proxy, "no_proxy" => no_proxy}
      names = values.keys.flat_map { |name| [name, name.upcase] }
      original = names.to_h { |name| [name, ENV.fetch(name, nil)] }
      names.each { |name| ENV[name] = values.fetch(name.downcase) }
      yield
    ensure
      original&.each { |name, value| ENV[name] = value }
    end
  end

  class ConnectionProxyHTTPClientTest < Minitest::Test
    cover Connection
    cover Core::ConnectionProxy

    def test_host_port_with_proxy
      connection = Connection.new(proxy_url: "https://user:pass@example.com")
      http_client = connection.send(:build_http_client, URI("https://example.com:8080/"))

      assert_predicate http_client, :proxy?
      assert_equal "example.com", http_client.address
      assert_equal 8080, http_client.port
    end

    def test_http_proxy_is_connected_to_without_tls
      http_client = Connection.new(proxy_url: "http://example.com:8080").send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_same false, http_client.instance_variable_get(:@proxy_use_ssl)
    end

    def test_https_proxy_is_connected_to_over_tls
      http_client = Connection.new(proxy_url: "https://user:pass@example.com:8443").send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_same true, http_client.instance_variable_get(:@proxy_use_ssl)
    end
  end
end
