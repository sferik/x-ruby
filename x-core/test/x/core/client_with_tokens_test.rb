# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientWithTokensTest < Minitest::Test
    cover_client

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN", expires_in: 7200}.to_json)
    end

    def test_a_copy_given_other_tokens_holds_none_of_the_expiration_time_and_scopes_of_the_client
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now + 60, scopes: %w[tweet.read])
      copy = client.with(access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN")

      assert_equal [nil, nil], [copy.expires_at, copy.scopes]
    end

    def test_a_copy_given_other_tokens_holds_none_of_the_token_hooks_of_the_client
      client = Client.new(**test_oauth2_credentials, save_tokens: ->(_) {}, load_tokens: -> {})
      copy = client.with(access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN")

      assert_equal [nil, nil], [copy.save_tokens, copy.load_tokens]
    end

    def test_a_copy_given_other_tokens_keeps_the_token_hooks_it_is_given
      save_tokens = ->(_) {}
      load_tokens = -> {}
      copy = Client.new(**test_oauth2_credentials, save_tokens: ->(_) {}).with(access_token: "OTHER_ACCESS_TOKEN", save_tokens:, load_tokens:)

      assert_equal [save_tokens, load_tokens], [copy.save_tokens, copy.load_tokens]
    end

    def test_a_copy_given_another_authenticator_holds_none_of_the_token_hooks_of_the_client
      client = Client.new(**test_oauth2_credentials, save_tokens: ->(_) {}, load_tokens: -> {})
      copy = client.with(authenticator: OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: "OTHER_ACCESS_TOKEN"))

      assert_equal [nil, nil], [copy.save_tokens, copy.load_tokens]
    end

    def test_a_copy_that_shares_the_authenticator_keeps_the_token_hooks_of_the_client
      save_tokens = ->(_) {}
      load_tokens = -> {}
      copy = Client.new(**test_oauth2_credentials, save_tokens:, load_tokens:).with(base_url: "https://api.x.com/1.1/")

      assert_equal [save_tokens, load_tokens], [copy.save_tokens, copy.load_tokens]
    end

    def test_a_copy_given_no_authenticator_shares_the_authenticator_and_keeps_the_token_hooks_of_the_client
      save_tokens = ->(_) {}
      client = Client.new(**test_oauth2_credentials, save_tokens:)
      copy = client.with(authenticator: nil)

      assert_same client.authenticator, copy.authenticator
      assert_same save_tokens, copy.save_tokens
    end

    def test_a_refresh_of_a_copy_given_another_user_s_tokens_takes_none_of_the_stored_tokens_of_the_client
      stored = OAuth2Tokens.new(access_token: TEST_ACCESS_TOKEN, refresh_token: "STORED_REFRESH_TOKEN")
      client = Client.new(**test_oauth2_credentials, load_tokens: -> { stored })
      copy = client.with(access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN", expires_at: Time.now - 5)
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 200, body: "{}")
      copy.get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"Authorization" => "Bearer NEW_ACCESS_TOKEN"}
      assert_requested :post, "https://api.x.com/2/oauth2/token", body: /refresh_token=OTHER_REFRESH_TOKEN/
    end
  end
end
