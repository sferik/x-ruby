# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream authenticates as the app, with the bearer token of a client that holds one, or one fetched with its API key
  # and secret, and a client that holds neither, as one that authenticates with OAuth 2.0 as a user, cannot stream
  class StreamingClientAuthenticationTest < Minitest::Test
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"
    # The credentials of a user that authorized the app without offline.access, which refresh nothing
    CREDENTIALS = {client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN}.freeze

    # Signs each request with its method and path, as a scheme of an application's own might
    class SigningAuthenticator < Authenticator
      def headers(request) = {AUTHENTICATION_HEADER => "Signed #{request.http_method} #{request.uri.path}"}
    end

    def setup
      @token_request = stub_request(:post, APP_ONLY_TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
      @client = Client.new(authenticator: SigningAuthenticator.new)
    end

    def test_an_oauth2_user_client_cannot_stream
      stream = stub_request(:get, STREAM_URL)
      client = Client.new(**test_oauth2_credentials)

      assert_raises(UnsupportedOperation) { client.streaming.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }
      assert_not_requested stream
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

    def test_a_stream_raises_before_it_sends_the_token_of_the_user
      error = assert_raises(UnsupportedOperation) { Client.new(**CREDENTIALS).streaming.stream("tweets/search/stream") { flunk "unexpected yield" } }

      assert_match(/OAuth 2.0 as a user/, error.message)
      assert_not_requested :get, "https://api.x.com/2/tweets/search/stream"
    end

    def test_a_stream_is_opened_with_it
      stub_request(:get, "https://api.x.com/2/tweets/sample/stream").with(headers: {"Authorization" => "Signed get /2/tweets/sample/stream"})
        .to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      streamed = []
      until_the_stream_ends { @client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |object| streamed << object } }

      assert_equal [{"data" => {"id" => "1"}}], streamed
    end
  end
end
