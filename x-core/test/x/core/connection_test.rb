require "net/http"
require "uri"
require_relative "../../test_helper"

module X
  class ConnectionTest < Minitest::Test
    cover Connection

    def setup
      @connection = Connection.new
    end

    def test_initialization_defaults
      assert_equal Connection::DEFAULT_OPEN_TIMEOUT, @connection.open_timeout
      assert_equal Connection::DEFAULT_READ_TIMEOUT, @connection.read_timeout
      assert_equal Connection::DEFAULT_WRITE_TIMEOUT, @connection.write_timeout
      assert_nil @connection.debug_output
      assert_nil @connection.proxy_url
    end

    def test_custom_initialization
      connection = Connection.new(open_timeout: 10, read_timeout: 20, write_timeout: 30, debug_output: $stderr,
        proxy_url: "http://example.com:8080")

      assert_equal 10, connection.open_timeout
      assert_equal 20, connection.read_timeout
      assert_equal 30, connection.write_timeout
      assert_equal $stderr, connection.debug_output
      assert_equal "http://example.com:8080", connection.proxy_url
    end

    def test_http_client_defaults
      http_client = @connection.send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_equal "api.x.com", http_client.address
      assert_equal 443, http_client.port
      assert_equal Connection::DEFAULT_OPEN_TIMEOUT, http_client.open_timeout
      assert_equal Connection::DEFAULT_READ_TIMEOUT, http_client.read_timeout
      assert_equal Connection::DEFAULT_WRITE_TIMEOUT, http_client.write_timeout
    end

    def test_http_client_leaves_retries_to_the_caller
      assert_equal 0, @connection.send(:build_http_client, URI("https://api.x.com/2/tweets")).max_retries
    end

    def test_http_client_keeps_a_connection_open_beyond_a_burst_of_requests
      assert_equal Connection::DEFAULT_KEEP_ALIVE_TIMEOUT, @connection.keep_alive_timeout
      assert_equal 30, @connection.send(:build_http_client, URI("https://api.x.com/2/tweets")).keep_alive_timeout
    end

    def test_http_client_keeps_a_connection_open_for_the_keep_alive_timeout_given
      connection = Connection.new(keep_alive_timeout: 5)

      assert_equal 5, connection.keep_alive_timeout
      assert_equal 5, connection.send(:build_http_client, URI("https://api.x.com/2/tweets")).keep_alive_timeout
    end

    def test_debug_output
      http_client = @connection.send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_nil http_client.instance_variable_get(:@debug_output)
    end

    def test_client_properties
      connection = Connection.new(open_timeout: 10, read_timeout: 20, write_timeout: 30, debug_output: $stderr,
        proxy_url: "https://proxy.com")
      http_client = connection.send(:build_http_client, URI("https://api.x.com/2/tweets"))

      assert_predicate http_client, :proxy?
      assert_equal 10, http_client.open_timeout
      assert_equal 20, http_client.read_timeout
      assert_equal 30, http_client.write_timeout
      assert_equal $stderr, http_client.instance_variable_get(:@debug_output)
    end

    def test_perform
      stub_request(:get, "http://example.com:80")
      request = Net::HTTP::Get.new(URI("http://example.com:80"))
      @connection.perform(request:)

      assert_requested :get, "http://example.com:80"
    end

    def test_no_host_or_port
      stub_request(:get, "http://api.x.com:443/2/tweets")
      request = Net::HTTP::Get.new(URI("http://api.x.com:443/2/tweets"))
      request.stub(:uri, URI("/2/tweets")) { @connection.perform(request:) }

      assert_requested :get, "http://api.x.com:443/2/tweets"
    end
  end

  class ConnectionIPv6Test < Minitest::Test
    include LocalServer

    cover Connection

    # The first net-http that can request a host named by an IPv6 literal, which Ruby 4.0 ships; the 0.6 of Ruby 3.4
    # builds the Host header of such a request without the brackets, then empties it, and raises before it connects
    NET_HTTP_WITH_IPV6_LITERALS = Gem::Version.new("0.8")

    def setup
      @connection = Connection.new
      skip "net-http #{Net::HTTP::VERSION} cannot request an IPv6 literal host" if net_http < NET_HTTP_WITH_IPV6_LITERALS
    end

    # The version of the net-http that Net::HTTP comes from
    def net_http = Gem::Version.new(Net::HTTP::VERSION)

    def teardown
      @connection.close
    end

    def test_perform_connects_to_an_ipv6_literal_host
      with_local_server(host: "::1") do |port|
        assert_kind_of Net::HTTPSuccess, @connection.perform(request: Net::HTTP::Get.new(URI("http://[::1]:#{port}/")))
      end
    rescue Errno::EADDRNOTAVAIL, Errno::EAFNOSUPPORT, SocketError => e
      skip "this host cannot serve ::1: #{e}"
    end

    def test_perform_stream_connects_to_an_ipv6_literal_host
      with_local_server(host: "::1", response: "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}") do |port|
        chunks = []
        @connection.perform_stream(request: Net::HTTP::Get.new(URI("http://[::1]:#{port}/"))) do |response|
          response.read_body { |chunk| chunks << chunk }
        end

        assert_equal ["{}"], chunks
      end
    rescue Errno::EADDRNOTAVAIL, Errno::EAFNOSUPPORT, SocketError => e
      skip "this host cannot serve ::1: #{e}"
    end
  end

  class ConnectionNetworkErrorTest < Minitest::Test
    cover Connection

    def setup
      @connection = Connection.new
    end

    def test_network_error
      stub_request(:get, "https://example.com").to_raise(Errno::ECONNREFUSED)
      request = Net::HTTP::Get.new(URI("https://example.com"))
      error = assert_raises(NetworkError) { @connection.perform(request:) }

      assert_equal "Network error: Connection refused - Exception from WebMock", error.message
    end

    [IOError, Net::HTTPBadResponse, Net::ProtocolError, OpenSSL::SSL::SSLError, SocketError, SystemCallError,
      Timeout::Error, Zlib::Error].each do |error_class|
      define_method(:"test_wraps_#{error_class.name.downcase.tr(":", "_")}") do
        stub_request(:get, "https://example.com").to_raise(error_class)
        request = Net::HTTP::Get.new(URI("https://example.com"))

        assert_raises(NetworkError) { @connection.perform(request:) }
      end
    end

    def test_wraps_the_errors_that_descend_from_those_it_names
      [Errno::ECONNABORTED, Errno::ENETDOWN, Net::ReadTimeout, Zlib::BufError,
        Net::HTTPClientException.new("407 Proxy Authentication Required", nil)].each do |error|
        stub_request(:get, "https://example.com").to_raise(error)

        assert_raises(NetworkError) { @connection.perform(request: Net::HTTP::Get.new(URI("https://example.com"))) }
      end
    end
  end
end
