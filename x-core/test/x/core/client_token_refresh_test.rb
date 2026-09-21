# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientTokenRefreshTest < Minitest::Test
    cover_client

    USERS_ME = "https://api.x.com/2/users/me"

    def setup
      @refresh = stub_token_refresh("NEW_ACCESS_TOKEN", "NEW_REFRESH_TOKEN")
    end

    def stub_token_refresh(access_token, refresh_token)
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token:, refresh_token:, expires_in: 7200}.to_json)
    end

    def stub_users_me(access_token, status: 200)
      stub_request(:get, USERS_ME).with(headers: {"Authorization" => "Bearer #{access_token}"})
        .to_return(status:, headers: {"Content-Type" => "application/json"}, body: '{"data":{"id":"1"}}')
    end

    def test_a_request_refreshes_an_expired_token_first
      stub_users_me("NEW_ACCESS_TOKEN")
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 1)

      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      assert_requested @refresh, times: 1
    end

    def test_a_request_leaves_an_unexpired_token_alone
      stub_users_me(TEST_ACCESS_TOKEN)
      Client.new(**test_oauth2_credentials, expires_at: Time.now + 3600).get("users/me")

      assert_not_requested @refresh
    end

    def test_a_rejected_token_is_refreshed_and_the_request_sent_again
      stub_users_me(TEST_ACCESS_TOKEN, status: 401)
      stub_users_me("NEW_ACCESS_TOKEN")
      client = Client.new(**test_oauth2_credentials)

      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      assert_requested @refresh, times: 1
    end

    def test_a_request_rejected_after_a_refresh_raises
      stub_users_me(TEST_ACCESS_TOKEN, status: 401)
      stub_users_me("NEW_ACCESS_TOKEN", status: 401)
      client = Client.new(**test_oauth2_credentials)

      assert_raises(Unauthorized) { client.get("users/me") }
      assert_requested @refresh, times: 1
    end

    def test_a_refused_refresh_of_a_rejected_token_raises_an_authorization_error
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 400, body: {error: "invalid_request", error_description: "Value passed for the token was invalid."}.to_json)
      stub_users_me(TEST_ACCESS_TOKEN, status: 401)
      error = assert_raises(AuthorizationError) { Client.new(**test_oauth2_credentials).get("users/me") }

      assert_equal ["Value passed for the token was invalid.", "invalid_request", 400], [error.message, error.error_code, error.status]
    end

    def test_a_refresh_that_returns_the_rejected_token_raises_without_sending_again
      stub_token_refresh(TEST_ACCESS_TOKEN, "NEW_REFRESH_TOKEN")
      stub_users_me(TEST_ACCESS_TOKEN, status: 401)
      client = Client.new(**test_oauth2_credentials)

      assert_raises(Unauthorized) { client.get("users/me") }
      assert_requested :get, USERS_ME, times: 1
    end

    def test_a_rejected_token_already_replaced_is_not_refreshed_again
      stub_users_me(TEST_ACCESS_TOKEN, status: 401)
      stub_users_me("REPLACED")
      authenticator = nil #: OAuth2Authenticator?
      client = Client.new(**test_oauth2_credentials, on_response: ->(_) { authenticator&.instance_variable_set(:@access_token, "REPLACED") })
      authenticator = client.authenticator
      authenticator.stub(:header, ->(_) { {"Authorization" => "Bearer #{authenticator.access_token}"} }) do
        client.get("users/me")
      end

      assert_not_requested @refresh
    end

    def test_a_subclass_of_the_oauth2_authenticator_refreshes_a_rejected_token
      stub_users_me(TEST_ACCESS_TOKEN, status: 401)
      stub_users_me("NEW_ACCESS_TOKEN")
      client = Client.new(**test_oauth2_credentials)
      client.instance_variable_set(:@authenticator, Class.new(OAuth2Authenticator).new(**test_oauth2_credentials))

      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      assert_equal "NEW_REFRESH_TOKEN", client.send(:refresh_token)
    end

    def test_other_clients_do_not_refresh_on_unauthorized
      stub_request(:get, USERS_ME).to_return(status: 401)

      [Client.new(bearer_token: TEST_BEARER_TOKEN), Client.new(**test_oauth_credentials)].each do |client|
        assert_raises(Unauthorized) { client.get("users/me") }
      end
      assert_requested :get, USERS_ME, times: 2
    end

    def test_the_client_reads_the_tokens_of_the_last_refresh
      client = Client.new(**test_oauth2_credentials)
      client.authenticator.refresh_token!

      assert_equal ["NEW_ACCESS_TOKEN", "NEW_REFRESH_TOKEN"], [client.send(:access_token), client.send(:refresh_token)]
      assert_in_delta Time.now + 7200, client.expires_at, 5
    end

    def test_on_token_refresh_receives_the_authenticator
      refreshed = []
      client = Client.new(**test_oauth2_credentials, on_token_refresh: ->(authenticator) { refreshed << authenticator })
      client.authenticator.refresh_token!

      assert_equal [client.authenticator], refreshed
    end

    def test_on_token_refresh_is_optional_and_a_copy_can_add_one
      client = Client.new(**test_oauth2_credentials)
      client.authenticator.refresh_token!
      refreshed = []
      copy = client.copy(on_token_refresh: ->(authenticator) { refreshed << authenticator.refresh_token })
      stub_token_refresh("NEWER_ACCESS_TOKEN", "NEWER_REFRESH_TOKEN")
      copy.authenticator.refresh_token!

      assert_equal ["NEWER_REFRESH_TOKEN"], refreshed
    end
  end

  class ClientTokenRefreshCredentialsTest < Minitest::Test
    cover_client

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
    end

    def test_expires_at_reaches_the_authenticator
      expires_at = Time.now + 60

      assert_equal expires_at, Client.new(**test_oauth2_credentials, expires_at:).authenticator.expires_at
    end

    def test_tokens_are_kept_when_another_set_authenticates
      client = Client.new(**test_oauth_credentials, **test_oauth2_credentials)

      assert_instance_of OAuth1Authenticator, client.authenticator
      assert_equal [TEST_REFRESH_TOKEN, TEST_ACCESS_TOKEN], [client.send(:refresh_token), client.send(:access_token)]
    end

    def test_expires_at_is_kept_without_oauth2
      expires_at = Time.now + 60

      assert_equal expires_at, Client.new(bearer_token: TEST_BEARER_TOKEN, expires_at:).expires_at
    end

    def test_a_copy_with_another_credential_keeps_the_refreshed_tokens
      client = Client.new(**test_oauth2_credentials)
      client.authenticator.refresh_token!
      copy = client.copy(client_secret: "NEW_CLIENT_SECRET")

      assert_equal ["NEW_ACCESS_TOKEN", "NEW_REFRESH_TOKEN"], [copy.authenticator.access_token, copy.authenticator.refresh_token]
      refute_operator copy.authenticator, :same_credentials?, client.authenticator
    end

    def test_a_copy_given_a_token_replaces_the_refreshed_one
      client = Client.new(**test_oauth2_credentials)
      client.authenticator.refresh_token!
      copy = client.copy(access_token: "GIVEN_ACCESS_TOKEN")

      assert_equal ["GIVEN_ACCESS_TOKEN", "NEW_REFRESH_TOKEN"], [copy.authenticator.access_token, copy.authenticator.refresh_token]
    end

    def test_an_oauth1_copy_signs_with_a_new_access_token
      copy = Client.new(**test_oauth_credentials).copy(access_token: "GIVEN_ACCESS_TOKEN")

      assert_equal "GIVEN_ACCESS_TOKEN", copy.authenticator.access_token
    end

    def test_a_copy_shares_the_authenticator_so_a_refresh_reaches_both
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now + 3600)
      copy = client.copy(base_url: "https://api.x.com/1.1/")
      copy.authenticator.refresh_token!

      assert_same client.authenticator, copy.authenticator
      assert_equal %w[NEW_REFRESH_TOKEN NEW_REFRESH_TOKEN], [client.send(:refresh_token), copy.send(:refresh_token)]
    end

    def test_a_refresh_calls_the_hook_of_each_client_that_shares_the_authenticator_once
      refreshed = []
      hook = ->(authenticator) { refreshed << [:client, authenticator.refresh_token] }
      client = Client.new(**test_oauth2_credentials, on_token_refresh: hook)
      copies = [client.copy(on_token_refresh: ->(authenticator) { refreshed << [:copy, authenticator.refresh_token] }), client.copy]
      copies.first.authenticator.refresh_token!

      assert_equal [[:client, "NEW_REFRESH_TOKEN"], [:copy, "NEW_REFRESH_TOKEN"]], refreshed.sort
    end

    def test_a_copy_joins_the_clients_that_share_the_authenticator
      client = Client.new(**test_oauth2_credentials)
      copy = client.copy
      clients = client.instance_variable_get(:@token_refresh_clients)

      assert_same clients, copy.instance_variable_get(:@token_refresh_clients)
      assert_equal [true, true], [clients[client], clients[copy]]
    end

    def test_a_copy_shares_a_subclass_of_the_oauth2_authenticator
      client = Client.new(**test_oauth2_credentials)
      authenticator = Class.new(OAuth2Authenticator).new(**test_oauth2_credentials)
      client.instance_variable_set(:@authenticator, authenticator)

      assert_same authenticator, client.copy.authenticator
    end

    def test_a_copy_of_a_refreshed_client_shares_its_authenticator
      client = Client.new(**test_oauth2_credentials)
      client.authenticator.refresh_token!

      assert_same client.authenticator, client.copy.authenticator
    end

    def test_a_copy_with_other_oauth2_credentials_has_its_own_authenticator
      client = Client.new(**test_oauth2_credentials)

      %i[client_id client_secret access_token refresh_token].each do |credential|
        refute_same client.authenticator, client.copy(credential => "OTHER").authenticator
      end
    end

    def test_an_oauth2_copy_of_a_client_without_oauth2_has_its_own_authenticator
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      copy = client.copy(**test_oauth2_credentials, bearer_token: nil)

      assert_instance_of OAuth2Authenticator, copy.authenticator
    end

    def test_a_copy_without_oauth2_shares_nothing
      client = Client.new(**test_oauth2_credentials)
      copy = client.copy(client_id: nil, client_secret: nil, access_token: nil, refresh_token: nil, bearer_token: TEST_BEARER_TOKEN)

      assert_instance_of BearerTokenAuthenticator, copy.authenticator
      oauth1 = Client.new(**test_oauth_credentials)

      refute_same oauth1.authenticator, oauth1.copy.authenticator
    end
  end
end
