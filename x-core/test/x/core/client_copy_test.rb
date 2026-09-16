require_relative "../../test_helper"

module X
  class ClientCopyTest < Minitest::Test
    cover Client

    def setup
      @client = Client.new(**test_oauth_credentials, base_url: "https://api.x.com/2/", open_timeout: 5, read_timeout: 6,
        write_timeout: 7, debug_output: $stdout, proxy_url: "http://proxy.example.com:8080", default_array_class: Set,
        default_object_class: OpenStruct, max_redirects: 3)
    end

    def test_copy_copies_the_credentials
      copy = @client.copy(base_url: "https://api.x.com/1.1/")

      assert_instance_of OAuth1Authenticator, copy.authenticator
      assert_equal [TEST_API_KEY, TEST_API_KEY_SECRET, TEST_ACCESS_TOKEN, TEST_ACCESS_TOKEN_SECRET],
        [copy.api_key, copy.api_key_secret, copy.access_token, copy.access_token_secret]
    end

    def test_copy_copies_the_other_credentials
      client = Client.new(**test_oauth2_credentials)
      copy = client.copy(base_url: "https://api.x.com/1.1/")

      assert_equal [TEST_CLIENT_ID, TEST_CLIENT_SECRET, TEST_REFRESH_TOKEN], [copy.client_id, copy.client_secret, copy.refresh_token]
      assert_equal TEST_BEARER_TOKEN, Client.new(bearer_token: TEST_BEARER_TOKEN).copy(max_redirects: 1).bearer_token
    end

    def test_copy_copies_the_settings
      copy = @client.copy(read_timeout: 60)

      assert_equal ["https://api.x.com/2/", 5, 60, 7, $stdout, "http://proxy.example.com:8080", Set, OpenStruct, 3],
        [copy.base_url, copy.open_timeout, copy.read_timeout, copy.write_timeout, copy.debug_output, copy.proxy_url,
          copy.default_array_class, copy.default_object_class, copy.max_redirects]
    end

    def test_copy_changes_the_base_url
      copy = @client.copy(base_url: "https://api.x.com/1.1/")

      assert_equal "https://api.x.com/1.1/", copy.base_url
      assert_equal "https://api.x.com/2/", @client.base_url
      refute_same @client, copy
    end

    def test_copy_removes_credentials
      copy = @client.copy(access_token: nil, access_token_secret: nil)

      assert_instance_of AppOnlyAuthenticator, copy.authenticator
      assert_nil copy.access_token
      assert_instance_of OAuth1Authenticator, @client.authenticator
    end

    def test_copy_without_options
      copy = @client.copy

      assert_equal @client.inspect, copy.inspect
      assert_equal [5, 6, 7, $stdout, "http://proxy.example.com:8080", Set, OpenStruct, 3],
        [copy.open_timeout, copy.read_timeout, copy.write_timeout, copy.debug_output, copy.proxy_url,
          copy.default_array_class, copy.default_object_class, copy.max_redirects]
    end
  end
end
