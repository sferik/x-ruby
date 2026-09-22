# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RequestContextTest < Minitest::Test
    include StreamHelpers

    # The errors that name the request they were raised for, and the parsers and the connection that build them
    cover Core::RequestContext
    cover Core::ResponseParser
    cover Core::StreamParser
    cover Connection
    cover HTTPError
    cover InvalidResponse
    cover NetworkError
    cover StreamingClient

    def setup
      # A client that raises at once, since these tests are about the error a failure raises rather than the
      # retries a client makes before it
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_retries: 0)
    end

    def test_the_error_of_a_refused_request_names_it
      stub_request(:get, "https://api.x.com/2/users/1").to_return(status: 404, headers: {"content-type" => "application/json"}, body: '{"errors": [{"message": "Could not find user"}]}')
      error = assert_raises(NotFound) { @client.get("users/1") }

      assert_equal "GET /2/users/1: Could not find user", error.message
      assert_equal [:get, URI("https://api.x.com/2/users/1")], [error.http_method, error.uri]
    end

    def test_the_error_of_a_write_names_the_method_it_was_sent_with
      stub_request(:post, "https://api.x.com/2/tweets").to_return(status: 403, headers: {"content-type" => "application/json"}, body: '{"detail": "Not allowed", "title": "Forbidden"}')
      error = assert_raises(Forbidden) { @client.post("tweets", {text: "Hello"}) }

      assert_equal "POST /2/tweets: Forbidden: Not allowed", error.message
      assert_equal :post, error.http_method
    end

    def test_the_message_leaves_the_query_out_while_the_uri_keeps_it
      stub_request(:get, "https://api.x.com/2/users?ids=1,2").to_return(status: 400, headers: {"content-type" => "application/json"}, body: '{"error": "Bad ids"}')
      error = assert_raises(BadRequest) { @client.get("users", params: {ids: [1, 2]}) }

      assert_equal "GET /2/users: Bad ids", error.message
      assert_equal "ids=1,2", error.uri.query
    end

    def test_the_error_of_a_request_that_got_no_response_names_it
      stub_request(:get, "https://api.x.com/2/users/1").to_raise(Errno::ECONNREFUSED)
      error = assert_raises(NetworkError) { @client.get("users/1") }

      assert_equal "GET /2/users/1: Network error: #{Errno::ECONNREFUSED.new("Exception from WebMock").message}", error.message
      assert_equal [:get, URI("https://api.x.com/2/users/1")], [error.http_method, error.uri]
    end

    def test_the_error_of_a_response_that_is_not_json_names_the_request
      stub_request(:get, "https://api.x.com/2/users/1").to_return(status: 200, headers: {"content-type" => "application/json"}, body: "<html>Not JSON</html>")
      error = assert_raises(InvalidResponse) { @client.get("users/1") }

      assert_equal "GET /2/users/1: The body of the 200 response is not JSON (application/json)", error.message
      assert_equal [:get, URI("https://api.x.com/2/users/1")], [error.http_method, error.uri]
    end

    def test_the_error_of_a_stream_the_api_refused_names_the_request
      stub_request(:get, "https://api.x.com/2/tweets/search/stream")
        .to_return(status: 401, body: '{"errors":[{"message":"Unauthorized"}]}', headers: {"Content-Type" => "application/json"})
      error = assert_raises(Unauthorized) { stream_and_collect("tweets/search/stream") }

      assert_equal "GET /2/tweets/search/stream: Unauthorized", error.message
      assert_equal [:get, URI("https://api.x.com/2/tweets/search/stream")], [error.http_method, error.uri]
    end

    def test_the_error_of_a_stream_line_that_is_not_json_names_the_request
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.define_singleton_method(:read_body) { |&block| block.call("<html>\r\n") }
      request = Net::HTTP::Get.new(URI("https://api.x.com/2/tweets/search/stream?expansions=author_id"))
      error = assert_raises(InvalidResponse) do
        Core::StreamParser.new.process(response:, response_parser: Core::ResponseParser.new, request:) { flunk "unexpected yield" }
      end

      assert_equal "GET /2/tweets/search/stream: The body of the 200 response is not JSON (no content type)", error.message
      assert_equal [:get, URI("https://api.x.com/2/tweets/search/stream?expansions=author_id")], [error.http_method, error.uri]
    end

    def test_an_error_built_without_a_request_names_none
      error = BadRequest.new(http_response: Net::HTTPBadRequest.new("1.1", "400", "Bad Request"))

      assert_equal "Bad Request", error.message
      assert_nil error.http_method
      assert_nil error.uri
    end

    def test_a_network_error_built_without_a_request_names_none
      error = NetworkError.new("Network error: Connection refused")

      assert_equal "Network error: Connection refused", error.message
      assert_nil error.http_method
      assert_nil error.uri
    end
  end
end
