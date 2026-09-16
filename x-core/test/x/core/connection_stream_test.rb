require "net/http"
require "uri"
require_relative "../../test_helper"

module X
  class ConnectionStreamTest < Minitest::Test
    cover Connection

    def setup
      @connection = Connection.new
    end

    def test_perform_stream
      stub_request(:get, "http://example.com:80")
      request = Net::HTTP::Get.new(URI("http://example.com:80"))
      response_received = false
      @connection.perform_stream(request:) do |response|
        response_received = true

        assert_kind_of Net::HTTPSuccess, response
      end

      assert response_received
      assert_requested :get, "http://example.com:80"
    end

    def test_perform_stream_reads_with_the_stream_read_timeout
      connection = Connection.new(read_timeout: 60, stream_read_timeout: 5)
      stub_request(:get, "https://example.com")
      request = Net::HTTP::Get.new(URI("https://example.com"))
      http_client = Net::HTTP.new("example.com", 443)
      connection.stub(:build_http_client, http_client) { connection.perform_stream(request:) { |_response| nil } }

      assert_equal [5, 60], [http_client.read_timeout, connection.read_timeout]
      assert_equal 20, Connection.new.stream_read_timeout
    end

    def test_perform_stream_network_error
      stub_request(:get, "https://example.com").to_raise(Errno::ECONNREFUSED)
      request = Net::HTTP::Get.new(URI("https://example.com"))
      error = assert_raises(NetworkError) do
        @connection.perform_stream(request:) { |_response| flunk "unexpected yield" }
      end

      assert_equal "Network error: Connection refused - Exception from WebMock", error.message
    end

    def test_perform_stream_no_host_or_port
      stub_request(:get, "http://api.twitter.com:443/2/tweets")
      request = Net::HTTP::Get.new(URI("http://api.twitter.com:443/2/tweets"))
      request.stub(:uri, URI("/2/tweets")) do
        @connection.perform_stream(request:) do |response|
          assert_kind_of Net::HTTPSuccess, response
        end
      end

      assert_requested :get, "http://api.twitter.com:443/2/tweets"
    end
  end
end
