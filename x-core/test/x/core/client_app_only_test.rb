# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientAppOnlyTest < Minitest::Test
    cover_client
    cover StreamingClient

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      @token_request = stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
    end

    def test_an_oauth1_client_copies_itself_with_a_bearer_token_fetched_once
      client = Client.new(**test_oauth_credentials, base_url: "https://api.x.com/2/")
      copies = [client.app_only, client.app_only]

      assert_equal [BearerTokenAuthenticator] * 2, copies.map { |copy| copy.authenticator.class }
      assert_requested @token_request, times: 1
    end

    def test_an_app_only_copy_keeps_the_settings_but_not_the_access_token
      copy = Client.new(**test_oauth_credentials, base_url: "https://api.x.com/2/").app_only

      assert_equal [TEST_BEARER_TOKEN, nil, nil, "https://api.x.com/2/"],
        [copy.send(:bearer_token), copy.send(:access_token), copy.send(:access_token_secret), copy.base_url]
    end

    def test_an_app_only_copy_holds_the_credentials_of_the_app_alone
      client = Client.new(**test_oauth_credentials, **test_oauth2_credentials.except(:client_secret), expires_at: Time.now + 60)
      copy = client.app_only

      assert_instance_of BearerTokenAuthenticator, copy.authenticator
      assert_equal({api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: TEST_BEARER_TOKEN}, copy.send(:credentials).compact)
    end

    def test_the_token_is_fetched_over_the_client_connection
      client = Client.new(**test_oauth_credentials)
      options = nil
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
      AppOnlyAuthenticator.stub(:new, ->(**given) {
        options = given
        authenticator
      }) { client.app_only }

      assert_same client.instance_variable_get(:@connection), options[:connection]
      assert_equal [TEST_API_KEY, TEST_API_KEY_SECRET], options.values_at(:api_key, :api_key_secret)
    end

    def test_an_app_only_client_fetches_its_token_over_the_client_connection
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, proxy_url: "http://proxy.example.com:8080", open_timeout: 5)

      assert_same client.instance_variable_get(:@connection), client.authenticator.connection
    end

    def test_an_oauth2_client_refreshes_its_token_over_the_client_connection
      client = Client.new(**test_oauth2_credentials, proxy_url: "http://proxy.example.com:8080", read_timeout: 5)

      assert_same client.instance_variable_get(:@connection), client.authenticator.connection
    end

    def test_the_client_connection_settings_reach_the_token_request
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, proxy_url: "http://proxy.example.com:8080")

      assert_equal "http://proxy.example.com:8080", client.authenticator.connection.send(:proxy_url)
    end

    def test_a_given_bearer_token_is_used_without_a_request
      client = Client.new(**test_oauth_credentials, bearer_token: "GIVEN")

      assert_equal "GIVEN", client.app_only.send(:bearer_token)
      assert_not_requested @token_request
    end

    def test_other_clients_are_already_app_only_enough
      [Client.new, Client.new(bearer_token: TEST_BEARER_TOKEN)].each do |client|
        assert_same client, client.app_only
      end
      assert_not_requested @token_request
    end

    def test_an_oauth2_user_client_holds_no_credentials_of_the_app
      client = Client.new(**test_oauth2_credentials)
      error = assert_raises(UnsupportedOperation) { client.app_only }

      assert_equal "A client that authenticates with OAuth 2.0 as a user holds no credentials of the app, so it " \
        "cannot authenticate as the app. Build a client from the app's bearer token, or its API key and secret, " \
        "instead", error.message
      assert_not_requested @token_request
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
      client.streaming(max_reconnects: 0).stream("tweets/sample/stream", object_class: ResponseBuilder) { |object| built << object }

      assert_same client, built.first[:client]
    end
  end
end
