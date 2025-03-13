require_relative "../test_helper"

module X
  class OAuthAuthenticatorTest < Minitest::Test
    cover OAuthAuthenticator

    def setup
      @authenticator = OAuthAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET,
        access_token: TEST_ACCESS_TOKEN, access_token_secret: TEST_ACCESS_TOKEN_SECRET)
    end

    def test_initialization
      assert_equal TEST_API_KEY, @authenticator.api_key
      assert_equal TEST_API_KEY_SECRET, @authenticator.api_key_secret
      assert_equal TEST_ACCESS_TOKEN, @authenticator.access_token
      assert_equal TEST_ACCESS_TOKEN_SECRET, @authenticator.access_token_secret
    end

    def test_default_oauth_nonce
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      SecureRandom.stub :hex, TEST_OAUTH_NONCE do
        authorization = @authenticator.header(request)["Authorization"]

        assert_includes authorization, "oauth_nonce=\"#{TEST_OAUTH_NONCE}\""
      end
    end

    def test_default_oauth_timestamp
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      Time.stub :now, Time.utc(1983, 11, 24) do
        authorization = @authenticator.header(request)["Authorization"]

        assert_includes authorization, "oauth_timestamp=\"#{TEST_OAUTH_TIMESTAMP}\""
      end
    end

    def test_header_contains_authorization_key
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      header = @authenticator.header(request)

      assert header.key?("Authorization"), "Header does not contain \"Authorization\" key"
    end

    def test_header_starts_with_oauth
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      authorization = @authenticator.header(request)["Authorization"]

      assert authorization.start_with?("OAuth ")
    end

    def test_header_contains_required_oauth_fields
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      authorization = @authenticator.header(request)["Authorization"]

      assert_includes authorization, "oauth_consumer_key=\"#{TEST_API_KEY}\""
      assert_includes authorization, "oauth_token=\"#{TEST_ACCESS_TOKEN}\""
    end

    def test_header_contains_oauth_signature_method
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      authorization = @authenticator.header(request)["Authorization"]

      assert_includes authorization, "oauth_signature_method=\"HMAC-SHA1\""
    end

    def test_header_contains_oauth_version
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      authorization = @authenticator.header(request)["Authorization"]

      assert_includes authorization, "oauth_version=\"1.0\""
    end

    def test_header_in_alphabetical_order
      request = Net::HTTP::Get.new(URI("https://example.com/"))
      authorization = @authenticator.header(request)["Authorization"]
      oauth_keys = authorization.scan(/oauth_[a-z0-9_]+/)

      assert_equal oauth_keys.sort, oauth_keys, "OAuth keys are not sorted in alphabetical order"
    end

    def test_signature
      request = Net::HTTP::Get.new(URI("https://example.com/?query=test"))
      expected = "OAuth oauth_consumer_key=\"TEST_API_KEY\", oauth_nonce=\"TEST_OAUTH_NONCE\", " \
                 "oauth_signature=\"1kHVZMzcNj51v60H63%2FTZErArAk%3D\", oauth_signature_method=\"HMAC-SHA1\", " \
                 "oauth_timestamp=\"438480000\", oauth_token=\"TEST_ACCESS_TOKEN\", oauth_version=\"1.0\""
      @authenticator.stub :default_oauth_params, test_oauth_params do
        authorization = @authenticator.header(request)["Authorization"]

        assert_equal expected, authorization
      end
    end

    def test_uri_without_query
      uri = URI("http://example.com/test?param=value")

      assert_equal "http://example.com/test", @authenticator.send(:uri_without_query, uri)

      uri_no_query = URI("http://example.com/test")

      assert_equal "http://example.com/test", @authenticator.send(:uri_without_query, uri_no_query)
    end

    def test_parse_query_params
      query_string = "param1=value1&param2=value2"
      expected = {"param1" => "value1", "param2" => "value2"}

      assert_equal expected, @authenticator.send(:parse_query_params, query_string)
    end

    def test_signature_base_string_with_spaces
      method = "GET"
      url = "https://api.twitter.com/2/tweets/search/recent"
      params = {"query" => "ruby has:media -is:retweet"}
      expected = "GET&https%3A%2F%2Fapi.twitter.com%2F2%2Ftweets%2Fsearch%2Frecent&query%3Druby%2520has%253Amedia%2520-is%253Aretweet"

      assert_equal expected, @authenticator.send(:signature_base_string, method, url, params)
    end
  end
end
