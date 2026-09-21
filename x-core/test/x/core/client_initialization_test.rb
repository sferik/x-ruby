# frozen_string_literal: true

require "ostruct"
require_relative "../../test_helper"

module X
  class ClientOAuthInitializationTest < Minitest::Test
    cover_client

    def test_initialize_oauth_credentials
      client = Client.new(**test_oauth_credentials)

      authenticator = client.authenticator

      assert_instance_of OAuth1Authenticator, authenticator
      assert_equal TEST_API_KEY, authenticator.api_key
      assert_equal TEST_ACCESS_TOKEN, authenticator.access_token
    end

    def test_inspect_hides_the_credentials
      client = Client.new(**test_oauth_credentials)

      assert_equal "#<X::Client base_url=\"https://api.x.com/2/\" authenticator=#<X::OAuth1Authenticator>>", client.inspect
    end

    def test_missing_api_key_or_secret
      %i[api_key api_key_secret].each do |missing_credential|
        assert_raises(ArgumentError) { Client.new(**test_oauth_credentials.except(missing_credential)) }
      end
    end

    def test_missing_access_token_and_secret_authenticates_as_the_app
      client = Client.new(**test_oauth_credentials.except(:access_token, :access_token_secret))

      assert_instance_of AppOnlyAuthenticator, client.authenticator
    end
  end

  class ClientOAuth2InitializationTest < Minitest::Test
    cover_client

    def test_initialize_oauth2_credentials
      client = Client.new(**test_oauth2_credentials)

      authenticator = client.authenticator

      assert_instance_of OAuth2Authenticator, authenticator
      assert_equal TEST_CLIENT_ID, authenticator.client_id
      assert_equal TEST_ACCESS_TOKEN, authenticator.access_token
      assert_equal TEST_REFRESH_TOKEN, authenticator.refresh_token
    end

    def test_initialize_a_public_oauth2_client_without_a_client_secret
      authenticator = Client.new(**test_oauth2_credentials.except(:client_secret)).authenticator

      assert_instance_of OAuth2Authenticator, authenticator
      assert_equal TEST_REFRESH_TOKEN, authenticator.refresh_token
    end

    def test_missing_oauth2_credentials
      %i[client_id access_token refresh_token].each do |missing_credential|
        assert_raises(ArgumentError) { Client.new(**test_oauth2_credentials.except(missing_credential)) }
      end
    end
  end

  class ClientAuthenticatorPrecedenceTest < Minitest::Test
    cover_client

    def test_oauth1_takes_precedence_over_oauth2
      client = Client.new(**test_oauth_credentials, client_id: TEST_CLIENT_ID, client_secret: TEST_CLIENT_SECRET,
        refresh_token: TEST_REFRESH_TOKEN)

      assert_instance_of OAuth1Authenticator, client.authenticator
    end

    def test_oauth2_takes_precedence_over_bearer_token
      client = Client.new(**test_oauth2_credentials, bearer_token: TEST_BEARER_TOKEN)

      assert_instance_of OAuth2Authenticator, client.authenticator
    end

    def test_a_bearer_token_alone_authenticates_with_it
      client = Client.new(bearer_token: "bearer_token")

      assert_equal "bearer_token", client.send(:bearer_token)
      assert_instance_of BearerTokenAuthenticator, client.authenticator
    end
  end

  class ClientConnectionOptionsTest < Minitest::Test
    cover_client

    def test_initialize_with_default_connection_options
      client = Client.new
      connection = client.instance_variable_get(:@connection)

      assert_equal Connection::DEFAULT_OPEN_TIMEOUT, connection.open_timeout
      assert_equal Connection::DEFAULT_READ_TIMEOUT, connection.read_timeout
      assert_equal Connection::DEFAULT_WRITE_TIMEOUT, connection.write_timeout
      assert_nil connection.debug_output
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
    cover_client

    def test_defaults
      client = Client.new

      assert_equal "https://api.x.com/2/", client.base_url
      assert_equal 10, client.max_redirects
      assert_equal Hash, client.default_object_class
      assert_equal Array, client.default_array_class
    end

    def test_a_slash_ends_the_base_url
      client = Client.new(base_url: "https://api.x.com/2")

      assert_equal "https://api.x.com/2/", client.base_url
      assert_equal "https://api.x.com/1.1/", client.copy(base_url: "https://api.x.com/1.1").base_url
    end

    def test_requests_keep_the_last_segment_of_a_base_url_without_a_slash
      stub_request(:get, "https://api.x.com/2/users/me")
      Client.new(base_url: "https://api.x.com/2").get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me"
    end

    def test_overwrite_defaults
      client = Client.new(base_url: "https://api.x.com/1.1/", max_redirects: 5,
        default_object_class: OpenStruct, default_array_class: Set)

      assert_equal "https://api.x.com/1.1/", client.base_url
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

  class ClientAppOnlyInitializationTest < Minitest::Test
    cover_client

    def test_initialize_app_only_credentials
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)

      assert_instance_of AppOnlyAuthenticator, client.authenticator
      assert_equal TEST_API_KEY, client.authenticator.api_key
    end

    def test_inspect_hides_the_credentials
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)

      assert_equal "#<X::Client base_url=\"https://api.x.com/2/\" authenticator=#<X::AppOnlyAuthenticator>>", client.inspect
    end

    def test_a_bearer_token_takes_precedence
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: TEST_BEARER_TOKEN)

      assert_instance_of BearerTokenAuthenticator, client.authenticator
    end

    def test_requests_fetch_the_bearer_token
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL).to_return(status: 200, body: {access_token: TEST_BEARER_TOKEN}.to_json)
      stub_request(:get, "https://api.x.com/2/tweets/1").with(headers: {"Authorization" => "Bearer #{TEST_BEARER_TOKEN}"})
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
      2.times { client.get("tweets/1") }

      assert_requested :post, AppOnlyAuthenticator::TOKEN_URL, times: 1
      assert_requested :get, "https://api.x.com/2/tweets/1", times: 2
    end

    def test_a_copy_given_access_tokens_switches_to_oauth
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
      copy = client.copy(access_token: TEST_ACCESS_TOKEN, access_token_secret: TEST_ACCESS_TOKEN_SECRET)

      assert_instance_of OAuth1Authenticator, copy.authenticator
    end
  end
end
