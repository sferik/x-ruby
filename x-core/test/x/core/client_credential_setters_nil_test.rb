# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientCredentialSettersNilTest < Minitest::Test
    cover_client

    def test_each_setter_clears_its_credential_when_given_nil
      %i[api_key api_key_secret access_token access_token_secret bearer_token client_id client_secret refresh_token].each do |name|
        client = Client.new(**test_oauth_credentials, bearer_token: TEST_BEARER_TOKEN, client_id: TEST_CLIENT_ID, client_secret: TEST_CLIENT_SECRET, refresh_token: TEST_REFRESH_TOKEN)
        client.public_send(:"#{name}=", nil)

        assert_nil client.public_send(name)
      end
    end
  end
end
