# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client keeps the credentials that are secrets to itself, and so must the authenticator it signs with, which
  # every client hands out. A reader of one is a way around the other.
  class CredentialPrivacyTest < Minitest::Test
    cover_client
    cover Authenticator
    cover OAuth1Authenticator
    cover OAuth2Authenticator
    cover AppOnlyAuthenticator
    cover BearerTokenAuthenticator

    SECRETS = %i[api_key_secret access_token_secret client_secret bearer_token].freeze

    def authenticators
      [Authenticator.new,
        OAuth1Authenticator.new(**test_oauth_credentials),
        OAuth2Authenticator.new(**test_oauth2_credentials),
        AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: TEST_BEARER_TOKEN),
        BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN)]
    end

    def test_no_authenticator_reveals_a_secret
      authenticators.each do |authenticator|
        SECRETS.each { |secret| refute_respond_to authenticator, secret, "#{authenticator.class} reveals #{secret}" }
      end
    end

    def test_no_client_reveals_the_secrets_of_its_authenticator
      [test_oauth_credentials, test_oauth2_credentials, {bearer_token: TEST_BEARER_TOKEN}].each do |credentials|
        client = Client.new(**credentials)

        SECRETS.each { |secret| refute_respond_to client.authenticator, secret }
      end
    end

    # The signature is the only way left to tell that a client passed each credential on to its authenticator, now
    # that no secret is readable, so a request signed with a credential changed must differ from one signed without.
    def authorization_for(**changes)
      sent = nil
      stub_request(:get, "https://api.x.com/2/tweets").with do |request|
        sent = request.headers["Authorization"]
        true
      end.to_return(body: "{}", headers: {"Content-Type" => "application/json"})
      SecureRandom.stub(:hex, TEST_OAUTH_NONCE) do
        Time.stub(:now, Time.utc(1983, 11, 24)) { Client.new(**test_oauth_credentials.merge(changes)).get("tweets") }
      end
      sent
    end

    def test_a_client_signs_with_each_credential_it_was_given
      baseline = authorization_for

      assert baseline.start_with?("OAuth ")
      %i[api_key api_key_secret access_token access_token_secret].each do |credential|
        refute_equal baseline, authorization_for(credential => "OTHER"), "#{credential} never reaches the signature"
      end
    end
  end
end
