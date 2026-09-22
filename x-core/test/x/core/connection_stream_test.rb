# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "../../test_helper"

module X
  class ConnectionStreamTest < Minitest::Test
    include LocalServer

    cover Connection
    cover Core::StreamCallbackError

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

      assert_equal "GET /: Network error: #{Errno::ECONNREFUSED.new("Exception from WebMock").message}", error.message
    end

    def test_perform_stream_reports_a_connection_that_drops_while_reading_as_a_network_error
      truncated = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n8\r\n{\"data\":\r\n"
      with_local_server(response: truncated) do |port|
        request = Net::HTTP::Get.new(URI("http://127.0.0.1:#{port}/"))

        assert_raises(NetworkError) { @connection.perform_stream(request:) { |response| response.read_body { |_chunk| } } }
      end
    end

    def test_perform_stream_raises_the_error_a_callback_of_the_stream_raised
      stub_request(:get, "http://example.com:80")
      request = Net::HTTP::Get.new(URI("http://example.com:80"))

      assert_raises(Errno::ECONNREFUSED) do
        @connection.perform_stream(request:) { |_response| raise Core::StreamCallbackError, Errno::ECONNREFUSED.new }
      end
    end

    def test_a_stream_callback_error_holds_the_error_a_callback_raised_and_its_message
      error = Core::StreamCallbackError.new(Errno::ECONNREFUSED.new("the hook failed"))

      assert_kind_of Errno::ECONNREFUSED, error.error
      assert_equal Errno::ECONNREFUSED.new("the hook failed").message, error.message
    end

    def test_perform_stream_no_host_or_port
      stub_request(:get, "http://api.x.com:443/2/tweets")
      request = Net::HTTP::Get.new(URI("http://api.x.com:443/2/tweets"))
      request.stub(:uri, URI("/2/tweets")) do
        @connection.perform_stream(request:) do |response|
          assert_kind_of Net::HTTPSuccess, response
        end
      end

      assert_requested :get, "http://api.x.com:443/2/tweets"
    end
  end
end
