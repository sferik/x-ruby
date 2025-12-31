require "ostruct"
require_relative "../test_helper"

module X
  class ClientOAuthInitializationTest < Minitest::Test
    cover Client

    def test_initialize_oauth_credentials
      client = Client.new(**test_oauth_credentials)

      authenticator = client.authenticator

      assert_instance_of OAuthAuthenticator, authenticator
      assert_equal TEST_API_KEY, authenticator.api_key
      assert_equal TEST_API_KEY_SECRET, authenticator.api_key_secret
      assert_equal TEST_ACCESS_TOKEN, authenticator.access_token
      assert_equal TEST_ACCESS_TOKEN_SECRET, authenticator.access_token_secret
    end

    def test_missing_oauth_credentials
      test_oauth_credentials.each_key do |missing_credential|
        client = Client.new(**test_oauth_credentials.except(missing_credential))

        assert_instance_of Authenticator, client.authenticator
      end
    end

    def test_setting_oauth_credentials
      client = Client.new
      test_oauth_credentials.each do |credential, value|
        client.public_send(:"#{credential}=", value)

        assert_equal value, client.public_send(credential)
      end

      assert_instance_of OAuthAuthenticator, client.authenticator
    end

    def test_setting_oauth_credentials_reinitializes_authenticator
      client = Client.new
      test_oauth_credentials.each do |credential, value|
        initialize_authenticator_called = false
        client.stub :initialize_authenticator, -> { initialize_authenticator_called = true } do
          client.public_send(:"#{credential}=", value)
        end

        assert initialize_authenticator_called, "Expected initialize_authenticator to be called"
      end
    end
  end

  class ClientOAuth2InitializationTest < Minitest::Test
    cover Client

    def test_initialize_oauth2_credentials
      client = Client.new(**test_oauth2_credentials)

      authenticator = client.authenticator

      assert_instance_of OAuth2Authenticator, authenticator
      assert_equal TEST_CLIENT_ID, authenticator.client_id
      assert_equal TEST_CLIENT_SECRET, authenticator.client_secret
      assert_equal TEST_ACCESS_TOKEN, authenticator.access_token
      assert_equal TEST_REFRESH_TOKEN, authenticator.refresh_token
    end

    def test_missing_oauth2_credentials
      test_oauth2_credentials.each_key do |missing_credential|
        client = Client.new(**test_oauth2_credentials.except(missing_credential))

        assert_instance_of Authenticator, client.authenticator
      end
    end

    def test_setting_oauth2_credentials
      client = Client.new
      test_oauth2_credentials.each do |credential, value|
        client.public_send(:"#{credential}=", value)

        assert_equal value, client.public_send(credential)
      end

      assert_instance_of OAuth2Authenticator, client.authenticator
    end

    def test_setting_oauth2_credentials_reinitializes_authenticator
      client = Client.new
      test_oauth2_credentials.each do |credential, value|
        initialize_authenticator_called = false
        client.stub :initialize_authenticator, -> { initialize_authenticator_called = true } do
          client.public_send(:"#{credential}=", value)
        end

        assert initialize_authenticator_called, "Expected initialize_authenticator to be called"
      end
    end
  end

  class ClientAuthenticatorPrecedenceTest < Minitest::Test
    cover Client

    def test_oauth1_takes_precedence_over_oauth2
      client = Client.new(**test_oauth_credentials, client_id: TEST_CLIENT_ID, client_secret: TEST_CLIENT_SECRET,
        refresh_token: TEST_REFRESH_TOKEN)

      assert_instance_of OAuthAuthenticator, client.authenticator
    end

    def test_oauth2_takes_precedence_over_bearer_token
      client = Client.new(**test_oauth2_credentials, bearer_token: TEST_BEARER_TOKEN)

      assert_instance_of OAuth2Authenticator, client.authenticator
    end

    def test_setting_bearer_token
      client = Client.new
      client.bearer_token = "bearer_token"

      assert_equal "bearer_token", client.bearer_token
      assert_instance_of BearerTokenAuthenticator, client.authenticator
    end

    def test_authenticator_remains_unchanged_if_no_new_credentials
      client = Client.new
      initial_authenticator = client.authenticator

      client.api_key = nil
      client.bearer_token = nil

      assert_equal initial_authenticator, client.authenticator
    end

    def test_initialize_authenticator_uses_instance_variable_not_accessor
      client = Client.new(**test_oauth_credentials)
      original_authenticator = client.authenticator
      clear_all_credentials(client)

      # If code uses accessor (nil), falls through to Authenticator.new; if @authenticator, preserves original
      client.stub(:authenticator, nil) { client.send(:initialize_authenticator) }

      assert_equal original_authenticator, client.authenticator
    end

    private

    def clear_all_credentials(client)
      %i[@api_key @api_key_secret @access_token @access_token_secret].each do |var|
        client.instance_variable_set(var, nil)
      end
      %i[@bearer_token @client_id @client_secret @refresh_token].each do |var|
        client.instance_variable_set(var, nil)
      end
    end
  end

  class ClientConnectionOptionsTest < Minitest::Test
    cover Client

    def test_initialize_with_default_connection_options
      client = Client.new
      connection = client.instance_variable_get(:@connection)

      assert_equal Connection::DEFAULT_OPEN_TIMEOUT, connection.open_timeout
      assert_equal Connection::DEFAULT_READ_TIMEOUT, connection.read_timeout
      assert_equal Connection::DEFAULT_WRITE_TIMEOUT, connection.write_timeout
      assert_equal Connection::DEFAULT_DEBUG_OUTPUT, connection.debug_output
      assert_nil connection.proxy_url
    end

    def test_initialize_connection_options
      client = Client.new(open_timeout: 10, read_timeout: 20, write_timeout: 30,
        debug_output: $stderr, proxy_url: "https://user:pass@proxy.com:42")
      connection = client.instance_variable_get(:@connection)

      assert_equal 10, connection.open_timeout
      assert_equal 20, connection.read_timeout
      assert_equal 30, connection.write_timeout
      assert_equal $stderr, connection.debug_output
      assert_equal "https://user:pass@proxy.com:42", connection.proxy_url
    end
  end

  class ClientDefaultsTest < Minitest::Test
    cover Client

    def test_defaults
      client = Client.new

      assert_equal "https://api.twitter.com/2/", client.base_url
      assert_equal 10, client.max_redirects
      assert_equal Hash, client.default_object_class
      assert_equal Array, client.default_array_class
    end

    def test_overwrite_defaults
      client = Client.new(base_url: "https://api.twitter.com/1.1/", max_redirects: 5,
        default_object_class: OpenStruct, default_array_class: Set)

      assert_equal "https://api.twitter.com/1.1/", client.base_url
      assert_equal 5, client.max_redirects
      assert_equal OpenStruct, client.default_object_class
      assert_equal Set, client.default_array_class
    end

    def test_passes_options_to_redirect_handler
      client = Client.new(max_redirects: 5)
      redirect_handler = client.instance_variable_get(:@redirect_handler)

      assert_equal client.instance_variable_get(:@connection), redirect_handler.connection
      assert_equal client.instance_variable_get(:@request_builder), redirect_handler.request_builder
      assert_equal 5, redirect_handler.instance_variable_get(:@max_redirects)
    end
  end
end
