# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A refresh takes the scopes X names of the token it issued, and keeps those it held when X names none, as OAuth 2.0
  # has it, and the tokens a refresh takes from the store bring their own
  class ClientScopesRefreshTest < Minitest::Test
    cover_client
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)
    cover Core.const_get(:TokenEndpoint)

    TOKEN_URL = "https://api.x.com/2/oauth2/token"
    SCOPES = %w[tweet.read users.read offline.access].freeze

    def stub_refresh(**body)
      stub_request(:post, TOKEN_URL).to_return(status: 200, body: {access_token: "NEW_ACCESS", refresh_token: "NEW_REFRESH", **body}.to_json)
    end

    def refreshed_scopes(**body)
      stub_refresh(**body)
      Client.new(**test_oauth2_credentials, scopes: SCOPES).tap { |client| client.authenticator.refresh! }.scopes
    end

    def test_a_refresh_takes_the_scopes_x_names
      scopes = refreshed_scopes(scope: "tweet.read  users.read")

      assert_equal [%w[tweet.read users.read], true, true], [scopes, scopes.frozen?, scopes.first.frozen?]
    end

    def test_a_refresh_that_names_no_scopes_keeps_those_held
      [{}, {scope: ""}, {scope: " "}, {scope: %w[tweet.read]}].each do |body|
        assert_equal SCOPES, refreshed_scopes(**body), body.inspect
      end
    end

    def test_save_tokens_is_passed_the_scopes_of_a_refresh
      stub_refresh(scope: "tweet.read")
      saved = []
      Client.new(**test_oauth2_credentials, scopes: SCOPES, save_tokens: ->(tokens) { saved << tokens.scopes }).authenticator.refresh!

      assert_equal [%w[tweet.read]], saved
    end

    def test_stored_tokens_taken_in_place_of_a_refresh_bring_their_scopes
      stored = OAuth2Tokens.new(access_token: "STORED_ACCESS", refresh_token: "STORED_REFRESH", expires_at: Time.now + 3600, scopes: %w[users.read])
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, scopes: SCOPES, expires_at: Time.now - 1, load_tokens: -> { stored })
      authenticator.headers(nil)

      assert_equal %w[users.read], authenticator.scopes
    end
  end
end
