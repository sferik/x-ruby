# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A GET request whose body the block reads raises the error of a response that failed before the block reads it,
  # the errors of a socket as a NetworkError, and any other error of the block as it was raised
  class ClientGetStreamErrorsTest < Minitest::Test
    cover_client
    cover Core.const_get(:Connection)

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      @responses = []
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(response) { @responses << response })
    end

    def test_a_failed_response_raises_its_error_once_on_response_is_passed_it
      stub_request(:get, STREAM_URL).to_return(status: 404, headers: {"Content-Type" => "application/json"}, body: "{\"title\":\"Not Found Error\",\"detail\":\"No stream\"}")
      error = assert_raises(NotFound) { @client.get_stream("tweets/sample/stream") { |_response| flunk "the block was called" } }

      assert_equal "GET /2/tweets/sample/stream: Not Found Error: No stream", error.message
      assert_equal [[404, :get, URI(STREAM_URL)]], @responses.map { |response| [response.status, response.http_method, response.uri] }
    end

    def test_a_successful_response_is_not_passed_to_on_response
      stub_request(:get, STREAM_URL)
      @client.get_stream("tweets/sample/stream") { |_response| }

      assert_empty @responses
    end

    def test_an_error_of_on_response_for_a_failed_response_is_raised_as_it_was
      stub_request(:get, STREAM_URL).to_return(status: 503)
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(_response) { raise IOError, "the hook failed" })

      assert_equal "the hook failed", assert_raises(IOError) { client.get_stream("tweets/sample/stream") { |_response| } }.message
    end

    def test_an_error_of_a_socket_the_block_raises_is_a_network_error
      stub_request(:get, STREAM_URL)
      error = assert_raises(NetworkError) { @client.get_stream("tweets/sample/stream") { |_response| raise IOError, "the body dropped" } }

      assert_equal "GET /2/tweets/sample/stream: Network error: the body dropped", error.message
    end

    def test_any_other_error_the_block_raises_is_raised_as_it_was
      stub_request(:get, STREAM_URL)
      error = assert_raises(ArgumentError) { @client.get_stream("tweets/sample/stream") { |_response| raise ArgumentError, "the block failed" } }

      assert_equal "the block failed", error.message
    end

    def test_an_unauthorized_the_block_raises_refreshes_no_token
      token_request = stub_request(:post, APP_ONLY_TOKEN_URL)
      stub_request(:get, STREAM_URL)
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "GIVEN")

      response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap { |unauthorized| unauthorized.uri = URI(STREAM_URL) }
      rejection = Unauthorized.new(http_response: response)

      assert_same rejection, assert_raises(Unauthorized) { client.get_stream("tweets/sample/stream") { |_response| raise rejection } }
      assert_not_requested token_request
      assert_requested :get, STREAM_URL, times: 1
    end

    def test_an_error_of_a_socket_while_connecting_is_a_network_error
      stub_request(:get, STREAM_URL).to_raise(Errno::ECONNREFUSED)

      assert_raises(NetworkError) { @client.get_stream("tweets/sample/stream") { |_response| flunk "the block was called" } }
    end
  end
end
