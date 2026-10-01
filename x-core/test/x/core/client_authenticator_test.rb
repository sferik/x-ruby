# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientAuthenticatorTest < Minitest::Test
    cover_client
    cover Core.const_get(:CredentialValidator)
    cover AppOnlyAuthenticator
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)

    def setup
      stub_request(:post, OAUTH2_TOKEN_URL)
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN", expires_in: 7200}.to_json)
      @app_token_request = stub_request(:post, APP_ONLY_TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
    end

    def test_a_client_authenticates_with_the_authenticator_it_is_given
      authenticator = BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN)
      client = Client.new(authenticator:)
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: {"Authorization" => "Bearer #{TEST_BEARER_TOKEN}"})
      client.get("users/me")

      assert_same authenticator, client.authenticator
      assert_equal "#<X::Client base_url=\"https://api.x.com/2/\" authenticator=#<X::BearerTokenAuthenticator>>", client.inspect
    end

    def test_an_authenticator_that_is_not_one_is_refused_without_revealing_it
      error = assert_raises(ArgumentError) { Client.new(authenticator: {bearer_token: "SECRET"}) }

      assert_equal "authenticator must be an X::Authenticator, such as an X::OAuth2Authenticator, or nil, not a Hash", error.message
    end

    def test_an_authenticator_is_refused_beside_credentials_which_it_is_not_given
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      error = assert_raises(ArgumentError) { Client.new(authenticator:, bearer_token: TEST_BEARER_TOKEN, expires_at: Time.now) }

      assert_equal "An authenticator holds the credentials it authenticates with, so it cannot be given beside " \
        "bearer_token, expires_at. Pass the authenticator, or the credentials, and leave out the other", error.message
      assert_empty authenticator.__send__(:clients).keys
    end

    def test_an_authenticator_is_allowed_beside_credentials_that_are_nil
      authenticator = Authenticator.new

      assert_same authenticator, Client.new(authenticator:, api_key: nil, expires_at: nil).authenticator
    end

    def test_the_refreshes_of_an_oauth2_authenticator_reach_each_client_given_it
      refreshed = []
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      clients = %i[first second].map { |name| Client.new(authenticator:, save_tokens: ->(tokens) { refreshed << [name, tokens.refresh_token] }) }
      authenticator.refresh!

      assert_equal [[:first, "NEW_REFRESH_TOKEN"], [:second, "NEW_REFRESH_TOKEN"]], refreshed.sort
      assert_equal [authenticator.expires_at] * 2, clients.map(&:expires_at)
    end

    def test_a_client_reads_the_expiration_time_of_an_oauth2_authenticator_it_is_given
      expires_at = Time.now + 60

      assert_equal expires_at, Client.new(authenticator: OAuth2Authenticator.new(**test_oauth2_credentials, expires_at:)).expires_at
    end

    def test_an_authenticator_sends_its_token_requests_over_the_connection_of_the_first_client_given_it
      [OAuth2Authenticator.new(**test_oauth2_credentials), AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)].each do |authenticator|
        first = Client.new(authenticator:)
        Client.new(authenticator:)

        assert_same internals(first).instance_variable_get(:@connection), authenticator.__send__(:connection)
      end
    end

    def test_an_authenticator_a_client_built_keeps_the_connection_of_that_client_when_given_to_another
      client = Client.new(**test_oauth2_credentials)
      Client.new(authenticator: client.authenticator)

      assert_same internals(client).instance_variable_get(:@connection), client.authenticator.__send__(:connection)
    end

    def test_a_client_given_an_app_only_authenticator_authenticates_as_the_app
      client = Client.new(authenticator: AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET))
      stub_request(:get, "https://api.x.com/2/tweets/1").with(headers: {"Authorization" => "Bearer #{TEST_BEARER_TOKEN}"})
      client.get("tweets/1")

      assert_same client, client.app_only
      assert_requested @app_token_request, times: 1
    end

    def test_a_client_given_an_oauth1_authenticator_fetches_the_app_token_with_its_api_key_and_secret
      [OAuth1Authenticator, Class.new(OAuth1Authenticator)].each do |authenticator_class|
        copy = Client.new(authenticator: authenticator_class.new(**test_oauth_credentials)).app_only

        assert_instance_of AppOnlyAuthenticator, copy.authenticator
        assert_equal({api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: TEST_BEARER_TOKEN}, internals(copy).send(:credentials).compact)
      end
      assert_requested @app_token_request.with(basic_auth: [TEST_API_KEY, TEST_API_KEY_SECRET]), times: 2
    end

    def test_a_client_given_an_oauth2_authenticator_holds_no_credentials_of_the_app
      client = Client.new(authenticator: OAuth2Authenticator.new(**test_oauth2_credentials))

      assert_raises(UnsupportedOperation) { client.app_only }
    end
  end
end
