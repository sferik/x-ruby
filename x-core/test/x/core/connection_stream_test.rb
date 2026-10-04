# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "../../test_helper"

module X
  class ConnectionStreamTest < Minitest::Test
    include LocalServer

    cover Core.const_get(:Connection)
    cover Core.const_get(:CallbackError)

    def setup
      @connection = Core.const_get(:Connection).new
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

    def test_perform_stream_raises_the_error_a_callback_of_the_stream_raised_tagged
      stub_request(:get, "http://example.com:80")
      request = Net::HTTP::Get.new(URI("http://example.com:80"))
      error = assert_raises(Core.const_get(:CallbackError)) do
        @connection.perform_stream(request:) { |_response| raise Core.const_get(:CallbackError), Errno::ECONNREFUSED.new }
      end

      assert_kind_of Errno::ECONNREFUSED, error.error
    end

    # Net::HTTP reads what is left of the body once the block of a request returns, which a stream never ends
    class HTTPReadingTheRest
      attr_writer :use_ssl

      def request(_request)
        yield Net::HTTPOK.new("1.1", "200", "OK")
        raise "the rest of the body was read"
      end
    end

    def test_perform_stream_returns_what_the_block_returns_without_reading_the_rest_of_the_body
      request = Net::HTTP::Get.new(URI("https://example.com/stream"))
      result = @connection.stub(:build_http_client, HTTPReadingTheRest.new) do
        @connection.perform_stream(request:) { |response| [:stopped, response.code] }
      end

      assert_equal [:stopped, "200"], result
    end

    def test_an_error_of_a_socket_is_one_a_request_raises_as_a_network_error
      assert Core.const_get(:Connection).network_error?(Errno::ECONNRESET.new)
      assert Core.const_get(:Connection).network_error?(IOError.new)
      refute Core.const_get(:Connection).network_error?(RuntimeError.new)
    end

    def test_a_callback_error_holds_the_error_a_callback_raised_and_its_message
      error = Core.const_get(:CallbackError).new(Errno::ECONNREFUSED.new("the hook failed"))

      assert_kind_of Errno::ECONNREFUSED, error.error
      assert_equal Errno::ECONNREFUSED.new("the hook failed").message, error.message
    end
  end
end
