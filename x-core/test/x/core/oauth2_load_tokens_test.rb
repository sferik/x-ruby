# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The tokens and endpoints of the tests of load_tokens
  module LoadTokensHelpers
    TOKEN_URL = "https://api.x.com/2/oauth2/token"
    USERS_ME = "https://api.x.com/2/users/me"

    # Tokens another process stored, whose access token expires at the time given
    def stored(expires_at: Time.now + 3600) = OAuth2Tokens.new(access_token: "STORED_ACCESS", refresh_token: "STORED_REFRESH", expires_at:)

    def stub_refresh(refresh_token, status: 200, body: {access_token: "NEW_ACCESS", refresh_token: "NEW_REFRESH", expires_in: 7200})
      stub_request(:post, TOKEN_URL).with(body: hash_including(refresh_token:)).to_return(status:, body: body.to_json)
    end

    def stub_users_me(access_token, status: 200)
      stub_request(:get, USERS_ME).with(headers: {"Authorization" => "Bearer #{access_token}"})
        .to_return(status:, headers: {"Content-Type" => "application/json"}, body: '{"data":{"id":"1"}}')
    end
  end

  # Processes that share the tokens of a user store each refresh with on_token_refresh, and read the store with
  # load_tokens before a refresh, since X accepts a refresh token once, and rotates it on the first refresh
  class OAuth2LoadTokensTest < Minitest::Test
    include LoadTokensHelpers

    cover_client
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)

    def setup
      @reported = []
      @loads = 0
    end

    # A client whose token has expired, which reads the store with a callable that returns each of the values given in
    # turn, and then the last of them
    def client_loading(*values, **options)
      Client.new(**test_oauth2_credentials, expires_at: Time.now - 1, on_token_refresh: ->(tokens) { @reported << tokens },
        load_tokens: -> { values.fetch([(@loads += 1) - 1, values.size - 1].min) }, **options)
    end

    def test_stored_tokens_that_have_not_expired_are_sent_without_a_refresh
      stub_users_me("STORED_ACCESS")
      client = client_loading(stored)

      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      assert_not_requested :post, TOKEN_URL
      assert_equal [[], "STORED_REFRESH"], [@reported, client.authenticator.__send__(:refresh_token)]
    end

    def test_stored_tokens_that_have_expired_are_refreshed_with_the_stored_refresh_token
      refresh = stub_refresh("STORED_REFRESH")
      stub_users_me("NEW_ACCESS")
      client_loading(stored(expires_at: Time.now - 1)).get("users/me")

      assert_requested refresh, times: 1
      assert_equal ["NEW_REFRESH"], @reported.map(&:refresh_token)
    end

    def test_stored_tokens_that_have_expired_are_refreshed_before_the_header_is_given
      refresh = stub_refresh("STORED_REFRESH")
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1, load_tokens: -> { stored(expires_at: Time.now - 1) })

      assert_equal({"Authorization" => "Bearer NEW_ACCESS"}, authenticator.headers(nil))
      assert_requested refresh, times: 1
    end

    def test_an_authenticator_clients_share_reads_the_store_with_the_first_load_tokens_among_them
      stub_users_me("STORED_ACCESS")
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1)
      clients = [Client.new(authenticator:), Client.new(authenticator:, load_tokens: -> { stored }), Client.new(authenticator:, load_tokens: -> {})]
      clients.last.get("users/me")

      assert_not_requested :post, TOKEN_URL
    end

    def test_a_rejected_token_is_sent_again_with_the_stored_tokens_without_a_refresh
      stub_users_me(TEST_ACCESS_TOKEN, status: 401)
      stub_users_me("STORED_ACCESS")
      client = Client.new(**test_oauth2_credentials, load_tokens: -> { stored })

      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      assert_not_requested :post, TOKEN_URL
    end

    def test_stored_tokens_taken_just_after_a_refresh_are_refreshed_when_rejected
      stub_refresh(TEST_REFRESH_TOKEN, body: {access_token: "SHORT_ACCESS", refresh_token: "SHORT_REFRESH", expires_in: 0})
      refresh = stub_refresh("STORED_REFRESH")
      stub_request(:get, USERS_ME).with(headers: {"Authorization" => "Bearer STORED_ACCESS"})
        .to_return({headers: {"Content-Type" => "application/json"}, body: '{"data":{"id":"1"}}'}, {status: 401})
      stub_users_me("NEW_ACCESS")
      client = client_loading(nil, stored)
      client.get("users/me")

      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      assert_requested refresh, times: 1
      assert_equal %w[SHORT_REFRESH NEW_REFRESH], @reported.map(&:refresh_token)
    end

    def test_a_refresh_refused_for_a_spent_refresh_token_takes_the_tokens_stored_since
      refresh = stub_refresh(TEST_REFRESH_TOKEN, status: 400, body: {error: "invalid_request", error_description: "Value passed for the token was invalid."})
      stub_users_me("STORED_ACCESS")
      client_loading(nil, stored).get("users/me")

      assert_requested refresh, times: 1
      assert_equal [2, []], [@loads, @reported]
    end

    def test_a_refresh_refused_for_a_spent_refresh_token_raises_when_the_store_holds_no_other
      stub_refresh(TEST_REFRESH_TOKEN, status: 400, body: {error: "invalid_grant"})
      held = OAuth2Tokens.new(access_token: TEST_ACCESS_TOKEN, refresh_token: TEST_REFRESH_TOKEN)

      assert_raises(AuthorizationError) { client_loading(held).get("users/me") }
      assert_equal 2, @loads
    end

    def test_a_refresh_refused_for_another_reason_raises_without_reading_the_store_again
      stub_refresh(TEST_REFRESH_TOKEN, status: 401, body: {error: "invalid_client"})

      assert_equal "invalid_client", assert_raises(AuthorizationError) { client_loading(nil, stored).get("users/me") }.error_code
      assert_equal 1, @loads
    end

    def test_a_store_that_holds_nothing_refreshes_as_without_one
      refresh = stub_refresh(TEST_REFRESH_TOKEN)
      stub_users_me("NEW_ACCESS")
      client_loading(nil).get("users/me")

      assert_requested refresh, times: 1
      assert_equal ["NEW_REFRESH"], @reported.map(&:refresh_token)
    end

    def test_stored_tokens_of_the_refresh_token_held_refresh_as_without_a_store
      refresh = stub_refresh(TEST_REFRESH_TOKEN)
      stub_users_me("NEW_ACCESS")
      client_loading(OAuth2Tokens.new(access_token: "OTHER", refresh_token: TEST_REFRESH_TOKEN)).get("users/me")

      assert_requested refresh, times: 1
    end
  end

  # load_tokens that returns what is not tokens, as a store that reads them back as a Hash would, raises from the
  # request, and the client keeps its own tokens
  class OAuth2LoadTokensTypeTest < Minitest::Test
    include LoadTokensHelpers

    cover Core.const_get(:OAuth2Refresh)

    # A client whose token has expired, which reads the store with a callable that returns each of the values given in
    # turn, and then the last of them
    def client_loading(*values)
      Client.new(**test_oauth2_credentials, expires_at: Time.now - 1, load_tokens: -> { values.shift || values.last })
    end

    def test_load_tokens_that_return_what_is_not_tokens_raise_without_taking_it
      client = client_loading(stored.to_h)
      error = assert_raises(TypeError) { client.get("users/me") }

      assert_equal "load_tokens must return an X::OAuth2Tokens, or nil for none in the store, not a Hash. Build the " \
        "tokens from what the store holds with X::OAuth2Tokens.new", error.message
      assert_equal TEST_ACCESS_TOKEN, internals(client).__send__(:access_token)
      assert_not_requested :post, TOKEN_URL
    end

    def test_a_client_recovers_once_load_tokens_returns_tokens
      stub_users_me("STORED_ACCESS")
      client = client_loading(stored.to_h, stored)

      assert_raises(TypeError) { client.get("users/me") }
      assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
    end

    def test_tokens_of_a_subclass_of_oauth2_tokens_are_taken
      stub_users_me("STORED_ACCESS")

      assert_equal({"data" => {"id" => "1"}}, client_loading(Class.new(OAuth2Tokens).new(**stored.to_h)).get("users/me"))
    end
  end

  # The load_tokens of an authenticator, which refresh! reads, and which comes before the load_tokens of its client
  class OAuth2AuthenticatorLoadTokensTest < Minitest::Test
    include LoadTokensHelpers

    cover_client
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)
    cover Core.const_get(:SettingValidator)

    def test_stored_tokens_of_the_refresh_token_a_refresh_spent_are_not_taken
      stub_refresh(TEST_REFRESH_TOKEN)
      stub_refresh("NEW_REFRESH", body: {access_token: "NEWER_ACCESS", refresh_token: "NEWER_REFRESH"})
      before = OAuth2Tokens.new(access_token: TEST_ACCESS_TOKEN, refresh_token: TEST_REFRESH_TOKEN)
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, load_tokens: -> { before })
      authenticator.refresh!

      assert_equal "NEWER_REFRESH", authenticator.refresh!.refresh_token
    end

    def test_stored_tokens_without_a_refresh_token_are_not_taken
      stub_refresh(TEST_REFRESH_TOKEN)
      stub_refresh("NEW_REFRESH", body: {access_token: "NEWER_ACCESS", refresh_token: "NEWER_REFRESH"})
      unrefreshed = OAuth2Tokens.new(access_token: "STORED_ACCESS")
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, load_tokens: -> { unrefreshed })
      authenticator.refresh!

      assert_equal "NEWER_REFRESH", authenticator.refresh!.refresh_token
    end

    def test_refresh_refreshes_with_the_stored_refresh_token
      refresh = stub_refresh("STORED_REFRESH")
      tokens = OAuth2Authenticator.new(**test_oauth2_credentials, load_tokens: -> { stored }).refresh!

      assert_requested refresh, times: 1
      assert_equal "NEW_REFRESH", tokens.refresh_token
    end

    def test_refresh_returns_the_stored_tokens_it_took_in_place_of_a_refusal
      stub_refresh(TEST_REFRESH_TOKEN, status: 400, body: {error: "invalid_request"})
      loads = [nil, stored]
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, load_tokens: -> { loads.shift })

      assert_equal stored.to_h.except(:expires_at), authenticator.refresh!.to_h.except(:expires_at)
    end

    def test_the_load_tokens_of_an_authenticator_come_before_those_of_its_client
      stub_users_me("STORED_ACCESS")
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now - 1, load_tokens: -> { stored })
      Client.new(authenticator:, load_tokens: -> { flunk "the client's load_tokens was read" }).get("users/me")

      assert_not_requested :post, TOKEN_URL
    end

    def test_a_copy_keeps_the_load_tokens_of_the_client
      load_tokens = -> { stored }

      assert_same load_tokens, Client.new(**test_oauth2_credentials, load_tokens:).with(max_retries: 0).load_tokens
    end

    def test_load_tokens_that_do_not_respond_to_call_are_refused
      message = "load_tokens must respond to call, as a Proc or a lambda does, or be nil, not a String"

      assert_equal message, assert_raises(ArgumentError) { Client.new(**test_oauth2_credentials, load_tokens: "store") }.message
      assert_equal message, assert_raises(ArgumentError) { OAuth2Authenticator.new(**test_oauth2_credentials, load_tokens: "store") }.message
    end
  end
end
