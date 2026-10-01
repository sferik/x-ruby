# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client given an authenticator in place of credentials reads the API key and client ID that are no secrets out of
  # it, as it reads the expiration time and scopes of an OAuth 2.0 authenticator, rather than answer nil for them.
  class ClientGivenAuthenticatorCredentialsTest < Minitest::Test
    cover_client

    def test_a_client_given_an_oauth1_authenticator_reads_its_api_key
      [OAuth1Authenticator, Class.new(OAuth1Authenticator)].each do |authenticator_class|
        client = Client.new(authenticator: authenticator_class.new(**test_oauth_credentials))

        assert_equal [TEST_API_KEY, nil], [client.api_key, client.client_id]
      end
    end

    def test_a_client_given_an_app_only_authenticator_reads_its_api_key
      [AppOnlyAuthenticator, Class.new(AppOnlyAuthenticator)].each do |authenticator_class|
        client = Client.new(authenticator: authenticator_class.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET))

        assert_equal [TEST_API_KEY, nil], [client.api_key, client.client_id]
      end
    end

    def test_a_client_given_an_oauth2_authenticator_reads_its_client_id
      [OAuth2Authenticator, Class.new(OAuth2Authenticator)].each do |authenticator_class|
        client = Client.new(authenticator: authenticator_class.new(**test_oauth2_credentials))

        assert_equal [nil, TEST_CLIENT_ID], [client.api_key, client.client_id]
      end
    end

    def test_a_client_given_a_bearer_token_authenticator_holds_neither
      client = Client.new(authenticator: BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN))

      assert_equal [nil, nil], [client.api_key, client.client_id]
    end

    def test_a_client_given_credentials_reads_the_ones_it_was_given
      assert_equal TEST_API_KEY, Client.new(**test_oauth_credentials).api_key
      assert_equal TEST_CLIENT_ID, Client.new(**test_oauth2_credentials).client_id
    end

    def test_a_copy_given_credentials_in_place_of_the_authenticator_reads_its_own
      client = Client.new(authenticator: OAuth1Authenticator.new(**test_oauth_credentials))
      copy = client.with(bearer_token: TEST_BEARER_TOKEN)

      assert_equal [nil, nil], [copy.api_key, copy.client_id]
    end
  end
end
