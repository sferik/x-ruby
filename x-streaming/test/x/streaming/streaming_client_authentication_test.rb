# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream authenticates as the app, with the bearer token of a client that holds one, or one fetched with its API key
  # and secret, and a client that holds neither, as one that authenticates with OAuth 2.0 as a user, streams as the
  # user, which X refuses with 403 Forbidden
  class StreamingClientAuthenticationTest < Minitest::Test
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"
    # The credentials of a user that authorized the app without offline.access, which refresh nothing
    CREDENTIALS = {client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN}.freeze
    # The response X refuses a stream opened with OAuth 2.0 as a user with
    FORBIDDEN = {status: 403, headers: {"Content-Type" => "application/json"}, body: {title: "Unsupported Authentication", detail: "Authenticating with OAuth 2.0 User Context is forbidden for this endpoint.", type: "https://api.twitter.com/2/problems/unsupported-authentication", status: 403}.to_json}.freeze

    # Signs each request with its method and path, as a scheme of an application's own might
    class SigningAuthenticator < Authenticator
      def headers(request) = {AUTHENTICATION_HEADER => "Signed #{request.http_method} #{request.uri.path}"}
    end

    def setup
      @token_request = stub_request(:post, APP_ONLY_TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
      @client = Client.new(authenticator: SigningAuthenticator.new)
    end

    def test_an_oauth2_user_client_is_refused_a_stream_with_forbidden
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"}).to_return(FORBIDDEN)
      client = Client.new(**test_oauth2_credentials)

      assert_raises(Forbidden) { client.streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      assert_requested :get, STREAM_URL, times: 1
    end

    def test_an_oauth1_client_streams_with_the_bearer_token_and_builds_objects_with_itself
      client = Client.new(**test_oauth_credentials)
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer #{TEST_BEARER_TOKEN}"}).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      built = []
      until_the_stream_ends { client.streaming(max_reconnects: 0).stream("tweets/sample/stream", object_class: ResponseBuilder) { |object| built << object } }

      assert_same client, built.first[:client]
    end

    def test_an_oauth2_client_with_a_bearer_token_streams_as_the_app
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer APP_BEARER_TOKEN"}).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      client = Client.new(**test_oauth2_credentials, bearer_token: "APP_BEARER_TOKEN")
      objects = []
      until_the_stream_ends { client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |object| objects << object } }

      assert_equal [{"data" => {"id" => "1"}}], objects
    end

    def test_a_stream_of_a_client_that_refreshes_nothing_is_refused_with_forbidden
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(FORBIDDEN)
      error = assert_raises(Forbidden) { Client.new(**CREDENTIALS).streaming.stream("tweets/search/stream") { flunk "unexpected yield" } }

      assert_equal "Unsupported Authentication", error.problems.first.title
      assert_not_requested :post, APP_ONLY_TOKEN_URL
    end

    def test_a_stream_is_opened_with_it
      stub_request(:get, "https://api.x.com/2/tweets/sample/stream").with(headers: {"Authorization" => "Signed get /2/tweets/sample/stream"})
        .to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      streamed = []
      until_the_stream_ends { @client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |object| streamed << object } }

      assert_equal [{"data" => {"id" => "1"}}], streamed
    end

    def test_the_rules_of_a_client_that_signs_with_oauth1_are_read_as_the_app
      stub_request(:post, APP_ONLY_TOKEN_URL).to_return(status: 200, body: {token_type: "bearer", access_token: "APP_TOKEN"}.to_json)
      stub_request(:get, "https://api.x.com/2/tweets/search/stream/rules").with(headers: {"Authorization" => "Bearer APP_TOKEN"}).to_return(body: {"data" => [{"id" => "1", "value" => "ruby"}]}.to_json)

      assert_equal [StreamRule.new(id: 1, value: "ruby")], Client.new(**test_oauth_credentials).streaming.rules
    end

    def test_the_rules_of_a_client_that_cannot_authenticate_as_the_app_are_refused_with_forbidden
      stub_request(:get, "https://api.x.com/2/tweets/search/stream/rules").with(headers: {"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"}).to_return(status: 403)
      stub_request(:post, "https://api.x.com/2/tweets/search/stream/rules").with(headers: {"Authorization" => "Bearer #{TEST_ACCESS_TOKEN}"}).to_return(status: 403)
      streaming_client = Client.new(**test_oauth2_credentials).streaming

      assert_raises(Forbidden) { streaming_client.rules }
      assert_raises(Forbidden) { streaming_client.add_rules("ruby") }
    end
  end
end
