# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A copy that does not keep the authenticator of the client holds none of the client's token hooks, whatever the
  # client authenticates with, so that it can neither read the stored tokens of the client's user nor store over them
  class ClientWithTokensAuthenticatorTest < Minitest::Test
    cover_client

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN", expires_in: 7200}.to_json)
    end

    HOOKS = {save_tokens: ->(_) {}, load_tokens: -> {}}.freeze

    def hooks_of(copy) = [copy.save_tokens, copy.load_tokens]

    def test_a_copy_of_a_client_given_its_authenticator_that_is_given_a_credential_or_an_authenticator_holds_none_of_the_token_hooks
      client = Client.new(authenticator: OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN),
        save_tokens: ->(_) {}, load_tokens: -> {})
      other = OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: "OTHER_ACCESS_TOKEN")

      [{bearer_token: "APP_BEARER_TOKEN"}, {api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET}, {authenticator: other}].each do |options|
        assert_equal [nil, nil], client.with(**options).then { |copy| [copy.save_tokens, copy.load_tokens] }, options.keys
      end
    end

    def test_a_copy_of_a_client_given_its_authenticator_that_shares_it_keeps_the_token_hooks
      save_tokens = ->(_) {}
      load_tokens = -> {}
      authenticator = OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN)
      copy = Client.new(authenticator:, save_tokens:, load_tokens:).with(base_url: "https://api.x.com/1.1/")

      assert_same authenticator, copy.authenticator
      assert_equal [save_tokens, load_tokens], [copy.save_tokens, copy.load_tokens]
    end

    def test_a_user_client_derived_from_an_app_copy_takes_none_of_the_stored_tokens_of_the_first_user
      stored = OAuth2Tokens.new(access_token: "FIRST_USER_ACCESS_TOKEN", refresh_token: "FIRST_USER_REFRESH_TOKEN")
      client = Client.new(authenticator: OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN),
        load_tokens: -> { stored })
      user = OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN",
        expires_at: Time.now - 5)
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 200, body: "{}")
      client.with(bearer_token: "APP_BEARER_TOKEN").with(authenticator: user).get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"Authorization" => "Bearer NEW_ACCESS_TOKEN"}
      assert_requested :post, "https://api.x.com/2/oauth2/token", body: /refresh_token=OTHER_REFRESH_TOKEN/
    end

    def test_a_copy_of_a_client_that_does_not_use_oauth2_given_an_authenticator_or_a_credential_holds_none_of_the_token_hooks
      other = OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: "OTHER_ACCESS_TOKEN")
      clients = [Client.new(bearer_token: TEST_BEARER_TOKEN, **HOOKS), Client.new(**test_oauth_credentials, **HOOKS),
        Client.new(authenticator: BearerTokenAuthenticator.new(bearer_token: TEST_BEARER_TOKEN), **HOOKS)]
      copies = clients.product([{authenticator: other}, {bearer_token: "OTHER"}]).map { |client, options| client.with(**options) }

      assert_equal [[nil, nil]], copies.map { |copy| hooks_of(copy) }.uniq
    end

    def test_a_copy_of_a_bearer_client_given_oauth2_credentials_holds_none_of_the_token_hooks
      copy = Client.new(bearer_token: TEST_BEARER_TOKEN, **HOOKS).with(client_id: TEST_CLIENT_ID, access_token: "OTHER_ACCESS_TOKEN")

      assert_equal [nil, nil], hooks_of(copy)
    end

    def test_a_copy_of_a_client_that_does_not_use_oauth2_given_neither_keeps_the_token_hooks
      save_tokens = ->(_) {}
      copy = Client.new(bearer_token: TEST_BEARER_TOKEN, save_tokens:).with(base_url: "https://api.x.com/1.1/", authenticator: nil)

      assert_same save_tokens, copy.save_tokens
    end

    def test_a_user_client_derived_from_a_bearer_client_takes_none_of_the_stored_tokens_of_its_user
      stored = OAuth2Tokens.new(access_token: "FIRST_USER_ACCESS_TOKEN", refresh_token: "FIRST_USER_REFRESH_TOKEN")
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, load_tokens: -> { stored })
      user = OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN",
        expires_at: Time.now - 5)
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 200, body: "{}")
      client.with(authenticator: user).get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"Authorization" => "Bearer NEW_ACCESS_TOKEN"}
    end

    def test_a_copy_of_a_client_built_from_oauth2_credentials_given_the_access_token_it_holds_keeps_the_token_hooks
      copy = Client.new(**test_oauth2_credentials, **HOOKS).with(access_token: TEST_ACCESS_TOKEN)

      assert_equal HOOKS.values, hooks_of(copy)
    end
  end
end
