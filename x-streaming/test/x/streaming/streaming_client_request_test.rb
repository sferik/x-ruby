# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream is sent as a request of its client is, with its headers and credentials, to the origin of its base URL
  # alone, and passes on_response each object it delivers, and the response that refused it
  class StreamingClientRequestTest < Minitest::Test
    include StreamHelpers

    cover StreamingClient

    AUTHORIZATION = "Bearer #{TEST_BEARER_TOKEN}".freeze

    def setup
      @responses = []
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN, on_response: ->(response) { @responses << response })
    end

    # What a test reads of the summary of each object of a stream
    def summary_of(response) = [response.resource_count, response.rate_limit.remaining, response.http_method, response.uri.path]

    def authorization_sent_to(url)
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys
        .find { |signature| signature.uri.to_s.eql?(url) }&.headers.to_h["Authorization"]
    end

    def test_a_stream_sends_the_headers_of_its_client
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"X-Trace" => "abc"})
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "")
      until_the_stream_ends { client.streaming(max_reconnects: 0).stream("tweets/search/stream") { |object| object } }

      assert_requested :get, "https://api.x.com/2/tweets/search/stream", headers: {"X-Trace" => "abc"}
    end

    def test_a_header_of_a_stream_replaces_one_of_the_client
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"X-Trace" => "client"})
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "")
      until_the_stream_ends { client.streaming(max_reconnects: 0).stream("tweets/search/stream", headers: {"X-Trace" => "stream"}) { |object| object } }

      assert_requested :get, "https://api.x.com/2/tweets/search/stream", headers: {"X-Trace" => "stream"}
    end

    def test_a_header_of_a_stream_replaces_one_of_the_client_named_in_another_case
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"x-trace" => "client"})
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "")
      until_the_stream_ends { client.streaming(max_reconnects: 0).stream("tweets/search/stream", headers: {"X-Trace" => "stream"}) { |object| object } }

      assert_requested :get, "https://api.x.com/2/tweets/search/stream", headers: {"X-Trace" => "stream"}
    end

    def test_a_stream_of_the_base_url_carries_the_credentials
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "")
      stream_and_collect("tweets/search/stream")

      assert_equal AUTHORIZATION, authorization_sent_to("https://api.x.com:443/2/tweets/search/stream")
    end

    def test_a_stream_of_another_origin_carries_none
      stub_request(:get, "https://example.com/stream").to_return(body: "")
      stream_and_collect("https://example.com/stream")

      assert_nil authorization_sent_to("https://example.com:443/stream")
    end

    def test_on_response_receives_each_object_a_stream_delivers_before_it_is_yielded
      stub_request(:get, "https://api.x.com/2/tweets/sample/stream")
        .to_return(body: "{\"data\":{\"id\":\"1\"},\"includes\":{\"users\":[{\"id\":\"2\"}]}}\r\n\r\n{\"data\":{\"id\":\"3\"}}\r\n", headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "49", "x-rate-limit-reset" => "1"})
      events = []
      client = Client.new(on_response: ->(response) { events << summary_of(response) })
      until_the_stream_ends { client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |post| events << post.dig("data", "id") } }

      assert_equal [[2, 49, :get, "/2/tweets/sample/stream"], "1", [1, 49, :get, "/2/tweets/sample/stream"], "3"], events
    end

    def test_on_response_receives_a_failed_stream_before_the_error
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(status: 429, body: '{"title":"Too Many Requests"}', headers: {"Content-Type" => "application/json"})

      assert_raises(TooManyRequests) { @client.streaming(max_reconnects: 0).stream("tweets/search/stream") { flunk "unexpected yield" } }
      assert_equal [[:get, 429, '{"title":"Too Many Requests"}']], @responses.map { |response| [response.http_method, response.status, response.body] }
    end

    def test_stream_passes_itself_to_a_response_builder
      results = with_stubbed_stream(chunks: ["{\"data\":{\"id\":\"1\"}}\r\n"]) do
        stream_and_collect("tweets/search/stream", object_class: ResponseBuilder)
      end

      assert_equal({"data" => {"id" => "1"}}, results.first[:body])
      assert_same @client, results.first[:client]
    end

    def test_the_error_of_a_stream_the_api_refused_names_the_request
      stub_request(:get, "https://api.x.com/2/tweets/search/stream")
        .to_return(status: 401, body: '{"errors":[{"message":"Unauthorized"}]}', headers: {"Content-Type" => "application/json"})
      error = assert_raises(Unauthorized) { stream_and_collect("tweets/search/stream") }

      assert_equal "GET /2/tweets/search/stream: Unauthorized", error.message
      assert_equal [:get, URI("https://api.x.com/2/tweets/search/stream")], [error.http_method, error.uri]
    end
  end
end
