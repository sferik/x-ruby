require_relative "../../test_helper"

module X
  class ClientCredentialsValidationTest < Minitest::Test
    cover Client
    cover CredentialValidator

    def assert_incomplete(**credentials)
      error = assert_raises(ArgumentError) { Client.new(**credentials) }

      assert_equal CredentialValidator::INCOMPLETE_CREDENTIALS, error.message
    end

    def test_no_credentials_send_requests_without_them
      assert_instance_of Authenticator, Client.new.authenticator
    end

    def test_an_expiration_time_alone_is_no_credential
      assert_instance_of Authenticator, Client.new(expires_at: Time.now).authenticator
    end

    def test_an_expiration_time_that_is_not_a_time_is_refused
      error = assert_raises(ArgumentError) { Client.new(**test_oauth2_credentials, expires_at: 1_789_600_000) }

      assert_equal CredentialValidator::INVALID_EXPIRES_AT, error.message
    end

    def test_an_expiration_time_of_a_subclass_of_time_is_allowed
      expires_at = Class.new(Time).at(Time.now.to_i + 60)

      assert_same expires_at, Client.new(**test_oauth2_credentials, expires_at:).expires_at
    end

    def test_setting_an_expiration_time_that_is_not_a_time_is_refused
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now + 60)

      assert_raises(ArgumentError) { client.expires_at = "2026-09-16T00:00:00Z" }
      assert_kind_of Time, client.expires_at
    end

    def test_each_credential_alone_is_incomplete
      test_oauth_credentials.merge(test_oauth2_credentials).except(:api_key, :access_token).each do |name, value|
        assert_incomplete(name => value)
      end
    end

    def test_an_access_token_alone_is_incomplete
      assert_incomplete(access_token: TEST_ACCESS_TOKEN)
    end

    def test_an_api_key_alone_is_incomplete
      assert_incomplete(api_key: TEST_API_KEY)
    end

    def test_an_access_token_without_its_secret_is_incomplete_rather_than_app_only
      assert_incomplete(**test_oauth_credentials.except(:access_token_secret))
    end

    def test_an_access_token_beside_a_bearer_token_is_incomplete
      assert_incomplete(bearer_token: TEST_BEARER_TOKEN, access_token: TEST_ACCESS_TOKEN)
    end

    def test_other_credentials_beside_a_bearer_token_are_allowed
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, access_token_secret: TEST_ACCESS_TOKEN_SECRET, refresh_token: TEST_REFRESH_TOKEN)

      assert_instance_of BearerTokenAuthenticator, client.authenticator
    end

    def test_an_access_token_secret_beside_app_only_credentials_is_allowed
      client = Client.new(**test_oauth_credentials.except(:access_token))

      assert_instance_of AppOnlyAuthenticator, client.authenticator
    end

    def test_complete_sets_beside_other_credentials_are_allowed
      assert_instance_of OAuth1Authenticator, Client.new(**test_oauth_credentials, bearer_token: TEST_BEARER_TOKEN).authenticator
      assert_instance_of OAuth2Authenticator, Client.new(**test_oauth2_credentials, api_key: TEST_API_KEY).authenticator
    end

    def test_a_copy_with_an_incomplete_set_raises
      client = Client.new(**test_oauth_credentials)

      assert_raises(ArgumentError) { client.copy(access_token_secret: nil) }
    end

    def test_setting_one_credential_at_a_time_keeps_the_authenticator_until_a_set_is_complete
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      client.access_token = TEST_ACCESS_TOKEN

      assert_instance_of BearerTokenAuthenticator, client.authenticator
    end
  end
end
