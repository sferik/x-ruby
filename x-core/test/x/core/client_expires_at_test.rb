# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An expiration time is that of an OAuth 2.0 access token, which a client given no OAuth 2.0 credentials to
  # authenticate with would leave unused, so it is refused beside any others
  class ClientExpiresAtTest < Minitest::Test
    cover_client
    cover Core.const_get(:CredentialValidator)

    def test_an_expiration_time_alone_is_refused_as_unused
      assert_equal TEST_UNUSED_EXPIRES_AT, assert_raises(ArgumentError) { Client.new(expires_at: Time.now) }.message
    end

    def test_an_expiration_time_is_refused_beside_credentials_other_than_those_of_oauth2
      [{bearer_token: TEST_BEARER_TOKEN}, test_oauth_credentials, test_oauth_credentials.slice(:api_key, :api_key_secret)].each do |credentials|
        assert_equal TEST_UNUSED_EXPIRES_AT, assert_raises(ArgumentError) { Client.new(**credentials, expires_at: Time.now) }.message
      end
    end

    def test_oauth2_credentials_beside_oauth1_ones_are_refused_before_their_expiration_time
      error = assert_raises(ArgumentError) { Client.new(**test_oauth_credentials, client_id: TEST_CLIENT_ID, expires_at: Time.now) }

      assert_match(/\Aclient_id are OAuth 2.0 credentials/, error.message)
    end

    def test_an_expiration_time_is_allowed_beside_the_oauth2_credentials_the_client_authenticates_with
      expires_at = Time.now + 60
      [test_oauth2_credentials, test_oauth2_credentials.slice(:client_id, :access_token)].each do |credentials|
        client = Client.new(**credentials, bearer_token: TEST_BEARER_TOKEN, expires_at:)

        assert_same expires_at, client.expires_at
      end
    end

    def test_no_expiration_time_is_allowed_beside_any_credentials
      assert_instance_of BearerTokenAuthenticator, Client.new(bearer_token: TEST_BEARER_TOKEN, expires_at: nil).authenticator
    end
  end
end
