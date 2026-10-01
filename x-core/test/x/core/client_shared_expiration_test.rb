# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientSharedExpirationTest < Minitest::Test
    cover_client

    def test_a_copy_keeps_the_expiration_time_of_the_authenticator_it_shares
      expires_at = Time.now + 3600
      client = Client.new(**test_oauth2_credentials, expires_at:)
      copy = client.with

      assert_equal [expires_at, expires_at], [client.expires_at, copy.expires_at]
    end

    def test_a_copy_that_shares_the_authenticator_is_refused_another_expiration_time
      expires_at = Time.now + 60
      client = Client.new(**test_oauth2_credentials, expires_at:)
      error = assert_raises(ArgumentError) { client.with(expires_at: Time.now + 3600) }

      assert_equal "A copy that shares the access token of the client shares its expiration time and scopes, so it " \
        "cannot be given expires_at. Pass it beside the access token and refresh token it belongs to", error.message
      assert_equal expires_at, client.expires_at
    end

    def test_a_copy_that_shares_the_authenticator_is_refused_an_expiration_time_of_nil
      expires_at = Time.now + 60
      client = Client.new(**test_oauth2_credentials, expires_at:)

      assert_raises(ArgumentError) { client.with(expires_at: nil) }
      assert_equal expires_at, client.expires_at
    end

    def test_a_copy_given_the_tokens_the_authenticator_holds_is_refused_an_expiration_time
      client = Client.new(**test_oauth2_credentials)

      assert_raises(ArgumentError) { client.with(**test_oauth2_credentials, expires_at: Time.now + 3600) }
    end

    def test_a_copy_given_tokens_of_its_own_takes_an_expiration_time
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now + 60)
      expires_at = Time.now + 3600
      copy = client.with(access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN", expires_at:)

      refute_same client.authenticator, copy.authenticator
      assert_equal expires_at, copy.expires_at
      refute_equal expires_at, client.expires_at
    end
  end
end
