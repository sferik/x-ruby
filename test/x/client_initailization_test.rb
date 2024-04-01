require "ostruct"
require_relative "../test_helper"

module X
  class ClientInitializationTest < Minitest::Test
    cover Client

    def setup
      @client = Client.new
    end

    def oauth_credentials
      {
        api_key: TEST_API_KEY,
        api_key_secret: TEST_API_KEY_SECRET,
        access_token: TEST_ACCESS_TOKEN,
        access_token_secret: TEST_ACCESS_TOKEN_SECRET
      }
    end

    def test_initialize_oauth_credentials
      client = Client.new(**oauth_credentials)

      authenticator = client.instance_variable_get(:@authenticator)

      assert_instance_of OAuthAuthenticator, authenticator
      assert_equal TEST_API_KEY, authenticator.api_key
      assert_equal TEST_API_KEY_SECRET, authenticator.api_key_secret
      assert_equal TEST_ACCESS_TOKEN, authenticator.access_token
      assert_equal TEST_ACCESS_TOKEN_SECRET, authenticator.access_token_secret
    end

    def test_missing_oauth_credentials
      oauth_credentials.each_key do |missing_credential|
        client = Client.new(**oauth_credentials.except(missing_credential))

        assert_instance_of Authenticator, client.instance_variable_get(:@authenticator)
      end
    end

    def test_setting_oauth_credentials
      oauth_credentials.each do |credential, value|
        @client.public_send("#{credential}=", value)

        assert_equal value, @client.public_send(credential)
      end

      assert_instance_of OAuthAuthenticator, @client.instance_variable_get(:@authenticator)
    end

    def test_setting_oauth_credentials_reinitializes_authenticator
      oauth_credentials.each do |credential, value|
        initialize_authenticator_called = false
        @client.stub :initialize_authenticator, -> { initialize_authenticator_called = true } do
          @client.public_send("#{credential}=", value)
        end

        assert_equal value, @client.public_send(credential)
        assert initialize_authenticator_called, "Expected initialize_authenticator to be called"
      end
    end

    def test_setting_bearer_token
      @client.bearer_token = "bearer_token"

      authenticator = @client.instance_variable_get(:@authenticator)

      assert_equal "bearer_token", @client.bearer_token
      assert_instance_of BearerTokenAuthenticator, authenticator
    end

    def test_authenticator_remains_unchanged_if_no_new_credentials
      initial_authenticator = @client.instance_variable_get(:@authenticator)

      @client.api_key = nil
      @client.api_key_secret = nil
      @client.access_token = nil
      @client.access_token_secret = nil
      @client.bearer_token = nil

      new_authenticator = @client.instance_variable_get(:@authenticator)

      assert_equal initial_authenticator, new_authenticator
    end

    def test_initialize_with_default_connection_options
      connection = @client.instance_variable_get(:@connection)

      assert_equal Connection::DEFAULT_OPEN_TIMEOUT, connection.open_timeout
      assert_equal Connection::DEFAULT_READ_TIMEOUT, connection.read_timeout
      assert_equal Connection::DEFAULT_WRITE_TIMEOUT, connection.write_timeout
      assert_equal Connection::DEFAULT_DEBUG_OUTPUT, connection.debug_output
      assert_nil connection.proxy_url
    end

    def test_initialize_connection_options
      client = Client.new(open_timeout: 10, read_timeout: 20, write_timeout: 30, debug_output: $stderr, proxy_url: "https://user:pass@proxy.com:42")

      connection = client.instance_variable_get(:@connection)

      assert_equal 10, connection.open_timeout
      assert_equal 20, connection.read_timeout
      assert_equal 30, connection.write_timeout
      assert_equal $stderr, connection.debug_output
      assert_equal "https://user:pass@proxy.com:42", connection.proxy_url
    end

    def test_defaults
      @client = Client.new

      assert_equal "https://api.twitter.com/2/", @client.base_url
      assert_equal 10, @client.max_redirects
      assert_equal Hash, @client.default_object_class
      assert_equal Array, @client.default_array_class
    end

    def test_overwrite_defaults
      @client = Client.new(base_url: "https://api.twitter.com/1.1/", max_redirects: 5, default_object_class: OpenStruct,
        default_array_class: Set)

      assert_equal "https://api.twitter.com/1.1/", @client.base_url
      assert_equal 5, @client.max_redirects
      assert_equal OpenStruct, @client.default_object_class
      assert_equal Set, @client.default_array_class
    end

    def test_passes_options_to_redirect_handler
      client = Client.new(max_redirects: 5)
      connection = client.instance_variable_get(:@connection)
      request_builder = client.instance_variable_get(:@request_builder)
      redirect_handler = client.instance_variable_get(:@redirect_handler)
      max_redirects = redirect_handler.instance_variable_get(:@max_redirects)

      assert_equal connection, redirect_handler.connection
      assert_equal request_builder, redirect_handler.request_builder
      assert_equal 5, max_redirects
    end
  end
end
