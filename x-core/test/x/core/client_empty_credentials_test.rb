# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientEmptyCredentialsTest < Minitest::Test
    cover_client
    cover Core::CredentialValidator

    def test_an_empty_credential_is_refused
      %i[api_key api_key_secret access_token access_token_secret bearer_token client_id client_secret refresh_token].each do |name|
        error = assert_raises(ArgumentError) { Client.new(name => "") }

        assert_equal "#{name} is empty. Pass the credential, or leave it out, since an empty one authenticates nothing", error.message
      end
    end

    def test_a_credential_of_whitespace_alone_is_refused
      assert_raises(ArgumentError) { Client.new(bearer_token: " \t\n") }
    end

    def test_an_empty_credential_beside_a_complete_set_is_refused
      error = assert_raises(ArgumentError) { Client.new(**test_oauth_credentials, bearer_token: "") }

      assert_equal "bearer_token is empty. Pass the credential, or leave it out, since an empty one authenticates nothing", error.message
    end

    def test_an_empty_credential_of_a_complete_set_is_refused_as_empty_rather_than_incomplete
      error = assert_raises(ArgumentError) { Client.new(**test_oauth_credentials, access_token_secret: "") }

      assert_match(/\Aaccess_token_secret is empty/, error.message)
    end

    def test_copying_with_an_empty_credential_is_refused
      assert_raises(ArgumentError) { Client.new(**test_oauth_credentials).with(api_key: "") }
    end
  end
end
