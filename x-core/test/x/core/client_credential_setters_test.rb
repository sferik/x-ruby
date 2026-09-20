require_relative "../../test_helper"

module X
  class ClientCredentialSettersTest < Minitest::Test
    cover_client

    def test_setting_part_of_a_set_sends_requests_without_credentials
      {api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET}.each do |name, value|
        client = Client.new
        client.public_send(:"#{name}=", value)

        assert_instance_of Authenticator, client.authenticator
      end
    end

    def test_setting_all_but_one_credential_of_oauth1_never_signs_with_oauth1
      test_oauth_credentials.each_key do |missing|
        client = Client.new
        test_oauth_credentials.except(missing).each { |name, value| client.public_send(:"#{name}=", value) }
        expected = %i[access_token access_token_secret].include?(missing) ? AppOnlyAuthenticator : Authenticator

        assert_instance_of expected, client.authenticator
      end
    end

    def test_setting_all_but_one_credential_of_oauth2_sends_requests_without_credentials
      %i[client_id access_token refresh_token].each do |missing|
        client = Client.new
        test_oauth2_credentials.except(missing).each { |name, value| client.public_send(:"#{name}=", value) }

        assert_instance_of Authenticator, client.authenticator
      end
    end
  end
end
