# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientSharedExpirationTest < Minitest::Test
    cover_client

    def test_a_copy_without_an_expiration_time_clears_it_for_the_client
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now + 3600)
      copy = client.with(expires_at: nil)

      assert_same copy.authenticator, client.authenticator
      assert_nil client.expires_at
    end

    def test_a_copy_keeps_the_expiration_time_of_the_authenticator_it_shares
      expires_at = Time.now + 3600
      client = Client.new(**test_oauth2_credentials, expires_at:)
      copy = client.with

      assert_equal [expires_at, expires_at], [client.expires_at, copy.expires_at]
    end

    def test_a_copy_given_another_expiration_time_shares_the_authenticator_and_sets_it_for_both
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now + 60)
      expires_at = Time.now + 3600
      copy = client.with(expires_at:)

      assert_same client.authenticator, copy.authenticator
      assert_equal [expires_at, expires_at], [client.expires_at, copy.expires_at]
    end
  end
end
