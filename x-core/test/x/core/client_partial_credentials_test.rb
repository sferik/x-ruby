# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client holds every credential of a complete set, since it checks them as it is built, but it builds its
  # authenticator first: reading the credentials to check them reads the tokens of the OAuth 2.0 authenticator, so
  # there has to be one. Each builder is therefore given credentials that may not form a set, and takes none of them
  # unless its own set is whole.
  class ClientPartialCredentialsTest < Minitest::Test
    cover_client

    def test_oauth1_takes_none_of_its_credentials_unless_the_set_is_whole
      test_oauth_credentials.each_key do |missing|
        expected = %i[access_token access_token_secret].include?(missing) ? AppOnlyAuthenticator : Authenticator

        assert_instance_of expected, authenticator_for(test_oauth_credentials.except(missing))
      end
    end

    def test_oauth2_takes_none_of_its_credentials_unless_the_set_is_whole
      %i[client_id access_token].each do |missing|
        assert_instance_of Authenticator, authenticator_for(test_oauth2_credentials.except(missing))
      end
    end

    def test_oauth2_takes_a_client_id_and_access_token_without_a_refresh_token
      assert_instance_of OAuth2Authenticator, authenticator_for(test_oauth2_credentials.except(:refresh_token))
    end

    def test_the_app_takes_neither_its_api_key_nor_the_secret_alone
      [{api_key: TEST_API_KEY}, {api_key_secret: TEST_API_KEY_SECRET}].each do |credentials|
        assert_instance_of Authenticator, authenticator_for(credentials)
      end
    end

    private

    # The authenticator a client builds from credentials that may not form a complete set
    def authenticator_for(credentials)
      client = Client.new
      credentials.each { |name, value| client.instance_variable_set(:"@#{name}", value) }
      client.send(:built_authenticator)
    end
  end
end
