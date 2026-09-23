# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client that authenticates with OAuth 2.0 as a user may hold the credentials of the app beside the user's, and
  # authenticates as the app with them
  class ClientAppOnlyOAuth2Test < Minitest::Test
    cover_client

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      @token_request = stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
    end

    def test_an_oauth2_client_with_a_bearer_token_copies_itself_with_it
      client = Client.new(**test_oauth2_credentials, bearer_token: "APP_BEARER_TOKEN")
      copies = [client.app_only, client.app_only]

      assert_same(*copies)
      assert_equal({"Authorization" => "Bearer APP_BEARER_TOKEN"}, copies.first.authenticator.header(nil))
      assert_not_requested @token_request
    end

    def test_an_oauth2_client_with_an_api_key_and_secret_copies_itself_with_a_bearer_token_it_fetches
      client = Client.new(**test_oauth2_credentials, api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
      copy = client.app_only

      assert_equal({"Authorization" => "Bearer #{TEST_BEARER_TOKEN}"}, copy.authenticator.header(nil))
      assert_instance_of OAuth2Authenticator, client.authenticator
      assert_requested @token_request, times: 1
    end

    def test_an_oauth2_client_with_a_bearer_token_streams_as_the_app
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer APP_BEARER_TOKEN"}).to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      client = Client.new(**test_oauth2_credentials, bearer_token: "APP_BEARER_TOKEN")
      objects = []
      client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |object| objects << object }

      assert_equal [{"data" => {"id" => "1"}}], objects
    end
  end
end
