# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientAuthenticatorCopyTest < Minitest::Test
    cover_client

    def setup
      @authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
      @client = Client.new(authenticator: @authenticator)
    end

    def test_a_copy_shares_the_authenticator_the_client_was_given
      copy = @client.with(base_url: "https://api.x.com/1.1/")

      assert_same @authenticator, copy.authenticator
      assert_equal [true, true], [@authenticator.__send__(:clients)[@client], @authenticator.__send__(:clients)[copy]]
    end

    def test_a_copy_given_a_credential_authenticates_with_it_in_place_of_the_authenticator
      copy = @client.with(bearer_token: TEST_BEARER_TOKEN)

      assert_instance_of BearerTokenAuthenticator, copy.authenticator
      assert_same @authenticator, copy.with(authenticator: @authenticator).authenticator
    end

    def test_a_copy_given_nil_for_a_credential_holds_none
      assert_instance_of Authenticator, @client.with(access_token: nil).authenticator
    end

    def test_a_copy_given_nil_for_the_authenticator_holds_none
      assert_instance_of Authenticator, @client.with(authenticator: nil).authenticator
    end

    def test_a_copy_given_an_authenticator_authenticates_with_it_in_place_of_the_credentials
      other = OAuth2Authenticator.new(**test_oauth2_credentials)
      client = Client.new(**test_oauth2_credentials)

      assert_equal [other, other], [client.with(authenticator: other).authenticator, @client.with(authenticator: other).authenticator]
    end

    def test_a_copy_given_nil_for_the_authenticator_keeps_the_credentials_of_the_client
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      oauth2_client = Client.new(**test_oauth2_credentials)

      assert_equal({bearer_token: TEST_BEARER_TOKEN}, internals(client.with(authenticator: nil)).send(:credentials).compact)
      assert_same oauth2_client.authenticator, oauth2_client.with(authenticator: nil).authenticator
    end

    def test_a_copy_given_an_authenticator_beside_a_credential_is_refused
      assert_raises(ArgumentError) { Client.new.with(authenticator: @authenticator, bearer_token: TEST_BEARER_TOKEN) }
    end

    def test_a_copy_given_an_expiration_time_beside_the_authenticator_is_refused
      error = assert_raises(ArgumentError) { @client.with(expires_at: Time.now) }

      assert_equal "An authenticator holds the credentials it authenticates with, so it cannot be given beside " \
        "expires_at. Pass the authenticator, or the credentials, and leave out the other", error.message
    end

    def test_a_copy_given_the_credentials_the_authenticator_holds_shares_it
      assert_same @authenticator, @client.with(**test_oauth2_credentials).authenticator
    end
  end
end
