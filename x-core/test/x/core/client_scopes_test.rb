# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The scopes X granted an OAuth 2.0 access token are held beside it, by the tokens, the authenticator, and the
  # client, and are refused, as an expiration time is, by a client that would leave them unused
  class ClientScopesTest < Minitest::Test
    cover_client
    cover OAuth2Authenticator
    cover Core.const_get(:CredentialValidator)

    SCOPES = %w[tweet.read users.read offline.access].freeze
    UNUSED_SCOPES = "scopes are the scopes X granted an OAuth 2.0 access token, so they are given beside the " \
      "client_id and access_token the client authenticates with, rather than beside OAuth 1.0a credentials, a " \
      "bearer_token, an api_key and api_key_secret, or none, which would leave them unused. Leave them out"

    def test_a_client_holds_the_scopes_it_was_given
      client = Client.new(**test_oauth2_credentials, scopes: SCOPES)

      assert_equal [SCOPES, true], [client.scopes, client.scopes.frozen?]
      assert_equal SCOPES, client.authenticator.scopes
    end

    def test_the_scopes_held_are_frozen_apart_from_those_given
      given = [+"tweet.read"]
      client = Client.new(**test_oauth2_credentials, scopes: given)
      given.first << ".x"
      given << "users.read"

      assert_equal [%w[tweet.read], true, true], [client.scopes, client.scopes.frozen?, client.scopes.first.frozen?]
    end

    def test_scopes_of_a_subclass_of_array_are_held_as_an_array
      scopes = Client.new(**test_oauth2_credentials, scopes: Class.new(Array).new(%w[tweet.read])).scopes

      assert_equal [Array, %w[tweet.read]], [scopes.class, scopes]
    end

    def test_scopes_of_a_subclass_of_string_are_accepted
      assert_equal %w[tweet.read], Client.new(**test_oauth2_credentials, scopes: [Class.new(String).new("tweet.read")]).scopes
    end

    def test_a_client_built_of_tokens_holds_their_scopes
      tokens = OAuth2Tokens.new(access_token: TEST_ACCESS_TOKEN, refresh_token: TEST_REFRESH_TOKEN, scopes: SCOPES)

      assert_equal SCOPES, Client.new(client_id: TEST_CLIENT_ID, **tokens.to_h).scopes
      assert_equal SCOPES, OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, **tokens.to_h).scopes
    end

    def test_scopes_default_to_nil
      assert_nil Client.new(**test_oauth2_credentials).scopes
      assert_nil Client.new(bearer_token: TEST_BEARER_TOKEN).scopes
    end

    def test_scopes_are_refused_beside_credentials_other_than_those_of_oauth2
      [{}, {bearer_token: TEST_BEARER_TOKEN}, test_oauth_credentials, test_oauth_credentials.slice(:api_key, :api_key_secret)].each do |credentials|
        assert_equal UNUSED_SCOPES, assert_raises(ArgumentError) { Client.new(**credentials, scopes: SCOPES) }.message
      end
    end

    def test_scopes_are_refused_beside_an_authenticator
      assert_raises(ArgumentError) { Client.new(authenticator: OAuth2Authenticator.new(**test_oauth2_credentials), scopes: SCOPES) }
    end

    def test_a_copy_of_a_client_given_an_authenticator_is_refused_scopes_beside_it
      client = Client.new(authenticator: OAuth2Authenticator.new(**test_oauth2_credentials))
      error = assert_raises(ArgumentError) { client.with(scopes: SCOPES) }

      assert_match(/cannot be given beside scopes\./, error.message)
    end

    def test_scopes_that_are_not_an_array_of_scopes_are_refused
      ["tweet.read", ["tweet.read", nil], ["tweet.read", "tweet read"], [""], [:"tweet.read"], ['tweet"read'], ["tweet\\read"]].each do |scopes|
        assert_raises(ArgumentError, scopes.inspect) { Client.new(**test_oauth2_credentials, scopes:) }
        assert_raises(ArgumentError, scopes.inspect) { OAuth2Authenticator.new(**test_oauth2_credentials, scopes:) }
      end
    end

    def test_scopes_that_are_not_an_array_of_scopes_are_refused_as_such_whatever_the_credentials
      error = assert_raises(ArgumentError) { Client.new(bearer_token: TEST_BEARER_TOKEN, scopes: "tweet.read") }

      assert_equal "scopes must be an Array of Strings that each name a scope, such as %w[tweet.read users.read], " \
        "or nil if they are not known", error.message
    end

    def test_a_copy_keeps_the_scopes_of_the_authenticator_it_shares
      client = Client.new(**test_oauth2_credentials, scopes: SCOPES)

      assert_equal SCOPES, client.with(read_timeout: 5).scopes
    end

    def test_a_copy_that_shares_the_authenticator_is_refused_scopes
      client = Client.new(**test_oauth2_credentials, scopes: SCOPES)
      error = assert_raises(ArgumentError) { client.with(scopes: %w[tweet.read]) }

      assert_equal "A copy that shares the access token of the client shares its expiration time and scopes, so it " \
        "cannot be given scopes. Pass it beside the access token and refresh token it belongs to", error.message
      assert_match(/cannot be given expires_at or scopes\./, assert_raises(ArgumentError) { client.with(expires_at: nil, scopes: nil) }.message)
    end

    def test_a_copy_given_other_tokens_is_given_their_scopes
      client = Client.new(**test_oauth2_credentials, scopes: SCOPES)

      assert_equal %w[tweet.read], client.with(access_token: "OTHER", refresh_token: "OTHER_REFRESH", scopes: %w[tweet.read]).scopes
    end
  end
end
