# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class AuthenticatorCredentialsTest < Minitest::Test
    cover Core.const_get(:CredentialValidator)
    cover BearerTokenAuthenticator
    cover AppOnlyAuthenticator
    cover OAuth1Authenticator
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)

    OAUTH2_CREDENTIALS = {client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN, refresh_token: TEST_REFRESH_TOKEN}.freeze
    APP_CREDENTIALS = {api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET}.freeze

    def missing(name) = "#{name} is nil or empty. Pass the credential, which the authenticator cannot authenticate without"

    def empty(name) = "#{name} is empty. Pass the credential, or leave it out, since an empty one authenticates nothing"

    def assert_refused(message, &)
      assert_equal message, assert_raises(ArgumentError, &).message
    end

    def test_a_bearer_token_authenticator_refuses_a_missing_bearer_token
      [nil, "", " \n"].each do |bearer_token|
        assert_refused(missing(:bearer_token)) { BearerTokenAuthenticator.new(bearer_token:) }
      end
    end

    def test_a_bearer_token_authenticator_refuses_a_bearer_token_that_is_not_a_string
      assert_refused("bearer_token must be a String, not a Integer") { BearerTokenAuthenticator.new(bearer_token: 123) }
    end

    def test_an_oauth1_authenticator_refuses_each_credential_that_is_not_a_string
      test_oauth_credentials.each_key do |name|
        assert_refused("#{name} must be a String, not a Integer") { OAuth1Authenticator.new(**test_oauth_credentials, name => 123) }
      end
    end

    def test_an_oauth2_authenticator_refuses_each_credential_that_is_not_a_string
      {**OAUTH2_CREDENTIALS, client_secret: TEST_CLIENT_SECRET}.each_key do |name|
        assert_refused("#{name} must be a String, not a Symbol") { OAuth2Authenticator.new(**OAUTH2_CREDENTIALS, name => :token) }
      end
    end

    def test_an_oauth1_authenticator_refuses_each_missing_credential
      test_oauth_credentials.each_key do |name|
        [nil, "", " "].each do |value|
          assert_refused(missing(name)) { OAuth1Authenticator.new(**test_oauth_credentials, name => value) }
        end
      end
    end

    def test_an_app_only_authenticator_refuses_each_missing_credential
      APP_CREDENTIALS.each_key do |name|
        assert_refused(missing(name)) { AppOnlyAuthenticator.new(**APP_CREDENTIALS, name => "") }
      end
    end

    def test_an_app_only_authenticator_refuses_an_empty_bearer_token
      assert_refused(empty(:bearer_token)) { AppOnlyAuthenticator.new(**APP_CREDENTIALS, bearer_token: "") }
    end

    def test_an_app_only_authenticator_takes_a_bearer_token_or_none
      assert_equal ["Bearer #{TEST_BEARER_TOKEN}", true], [AppOnlyAuthenticator.new(**APP_CREDENTIALS, bearer_token: TEST_BEARER_TOKEN).headers(nil)["Authorization"],
        AppOnlyAuthenticator.new(**APP_CREDENTIALS).is_a?(AppOnlyAuthenticator)]
    end

    def test_an_oauth2_authenticator_refuses_each_missing_credential
      %i[client_id access_token].each do |name|
        assert_refused(missing(name)) { OAuth2Authenticator.new(**OAUTH2_CREDENTIALS, name => nil) }
      end
    end

    def test_an_oauth2_authenticator_takes_no_refresh_token_but_refuses_an_empty_one
      assert_instance_of OAuth2Authenticator, OAuth2Authenticator.new(**OAUTH2_CREDENTIALS, refresh_token: nil)
      assert_refused(empty(:refresh_token)) { OAuth2Authenticator.new(**OAUTH2_CREDENTIALS, refresh_token: " ") }
    end

    def test_an_oauth2_authenticator_refuses_an_empty_client_secret
      assert_refused(empty(:client_secret)) { OAuth2Authenticator.new(**OAUTH2_CREDENTIALS, client_secret: " ") }
    end

    def test_an_oauth2_authenticator_refuses_an_expires_at_that_is_not_a_time
      ["2026-09-28T00:00:00Z", 1_790_000_000].each do |expires_at|
        assert_refused(TEST_INVALID_EXPIRES_AT) { OAuth2Authenticator.new(**OAUTH2_CREDENTIALS, expires_at:) }
      end
    end

    def test_an_oauth2_authenticator_takes_a_client_secret_and_an_expires_at_or_neither
      expires_at = Time.now + 60
      authenticator = OAuth2Authenticator.new(**OAUTH2_CREDENTIALS, client_secret: TEST_CLIENT_SECRET, expires_at:)

      assert_equal [expires_at, nil], [authenticator.expires_at, OAuth2Authenticator.new(**OAUTH2_CREDENTIALS).expires_at]
    end
  end
end
