require "net/http"
require "uri"
require_relative "../test_helper"

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
