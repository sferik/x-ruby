require_relative "../../test_helper"

module X
  class ClientUpdateCredentialsTest < Minitest::Test
    cover Client

    def test_update_credentials_changes_several_credentials_at_once
      client = Client.new(**test_oauth_credentials)
      builds = []
      client.stub(:initialize_authenticator, -> { builds << [client.access_token, client.access_token_secret] }) do
        client.update_credentials(access_token: "1-NEW_TOKEN", access_token_secret: "NEW_SECRET")
      end

      assert_equal [%w[1-NEW_TOKEN NEW_SECRET]], builds
    end

    def test_update_credentials_builds_an_authenticator_from_the_changed_credentials
      client = Client.new(**test_oauth_credentials)
      client.update_credentials(access_token: "1-NEW_TOKEN", access_token_secret: "NEW_SECRET")

      assert_equal ["1-NEW_TOKEN", "NEW_SECRET"], [client.authenticator.access_token, client.authenticator.access_token_secret]
      assert_equal [TEST_API_KEY, TEST_API_KEY_SECRET], [client.api_key, client.api_key_secret]
    end

    def test_update_credentials_refuses_an_incomplete_set_and_leaves_the_client_as_it_was
      client = Client.new(**test_oauth_credentials)
      authenticator = client.authenticator
      error = assert_raises(ArgumentError) { client.update_credentials(access_token_secret: nil, bearer_token: nil, api_key: nil) }

      assert_equal TEST_INCOMPLETE_CREDENTIALS, error.message
      assert_same authenticator, client.authenticator
      assert_equal TEST_ACCESS_TOKEN_SECRET, client.access_token_secret
    end

    def test_update_credentials_refuses_an_unknown_credential
      client = Client.new(**test_oauth_credentials)
      error = assert_raises(ArgumentError) { client.update_credentials(password: "secret") }

      assert_equal "unknown keyword: :password", error.message
      assert_instance_of OAuth1Authenticator, client.authenticator
    end

    def test_update_credentials_names_every_unknown_credential
      client = Client.new(**test_oauth_credentials)
      error = assert_raises(ArgumentError) { client.update_credentials(password: "secret", pin: "1234") }

      assert_equal "unknown keyword: :password, :pin", error.message
    end

    def test_update_credentials_refuses_an_empty_credential_as_empty_rather_than_incomplete
      client = Client.new(**test_oauth_credentials)
      error = assert_raises(ArgumentError) { client.update_credentials(api_key: nil, access_token_secret: "") }

      assert_match(/\Aaccess_token_secret is empty/, error.message)
      assert_equal [TEST_API_KEY, TEST_ACCESS_TOKEN_SECRET], [client.api_key, client.access_token_secret]
    end

    def test_update_credentials_clears_every_credential
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      client.update_credentials(bearer_token: nil)

      assert_instance_of Authenticator, client.authenticator
    end

    def test_clearing_the_last_credential_stops_sending_it
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      client.bearer_token = nil

      assert_nil client.bearer_token
      assert_instance_of Authenticator, client.authenticator
      assert_empty client.authenticator.header(nil)
    end

    def test_clearing_a_credential_uses_the_next_complete_set
      client = Client.new(**test_oauth_credentials)
      client.access_token_secret = nil

      assert_instance_of AppOnlyAuthenticator, client.authenticator
    end

    def test_clearing_a_credential_of_an_incomplete_set_sends_no_credentials
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      client.access_token = TEST_ACCESS_TOKEN
      client.bearer_token = nil

      assert_instance_of Authenticator, client.authenticator
    end
  end
end
