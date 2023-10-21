require_relative "../test_helper"

module X
  # Tests for X::RequestBuilder class
  class RequestBuilderTest < Minitest::Test
    cover RequestBuilder

    def setup
      @authenticator = OAuthAuthenticator.new(TEST_API_KEY, TEST_API_KEY_SECRET, TEST_ACCESS_TOKEN,
        TEST_ACCESS_TOKEN_SECRET)
      @request_builder = RequestBuilder.new
    end

    def test_build_get_request
      expected = "OAuth oauth_consumer_key=\"TEST_API_KEY\", oauth_nonce=\"TEST_OAUTH_NONCE\", " \
                 "oauth_signature=\"pLoM%2FPf%2Fk9eqgzGKU%2FRKm7VZfW8%3D\", oauth_signature_method=\"HMAC-SHA1\", " \
                 "oauth_timestamp=\"438480000\", oauth_token=\"TEST_ACCESS_TOKEN\", oauth_version=\"1.0\""
      @authenticator.stub :default_oauth_params, test_oauth_params do
        request = @request_builder.build(@authenticator, :get, "https://example.com/resource")

        assert_equal "GET", request.method
        assert_equal URI("https://example.com/resource"), request.uri
        assert_equal expected, request["Authorization"]
        assert_equal "application/json; charset=utf-8", request["Content-Type"]
      end
    end

    def test_build_post_request
      expected = "OAuth oauth_consumer_key=\"TEST_API_KEY\", oauth_nonce=\"TEST_OAUTH_NONCE\", " \
                 "oauth_signature=\"V2YVQa2Mvk1uh9yOOmTk00v2GrU%3D\", oauth_signature_method=\"HMAC-SHA1\", " \
                 "oauth_timestamp=\"438480000\", oauth_token=\"TEST_ACCESS_TOKEN\", oauth_version=\"1.0\""

      @authenticator.stub :default_oauth_params, test_oauth_params do
        request = @request_builder.build(@authenticator, :post, "https://example.com/resource", body: "{}")

        assert_equal "POST", request.method
        assert_equal URI("https://example.com/resource"), request.uri
        assert_equal "{}", request.body
        assert_equal expected, request["Authorization"]
      end
    end

    def test_custom_headers
      request = @request_builder.build(@authenticator, :get, "https://example.com/resource",
        headers: {"User-Agent" => "Custom User Agent"})

      assert_equal "Custom User Agent", request["User-Agent"]
    end

    def test_unsupported_http_method
      exception = assert_raises ArgumentError do
        @request_builder.build(@authenticator, :unsupported, "https://example.com/resource")
      end

      assert_equal "Unsupported HTTP method: unsupported", exception.message
    end

    def test_escape_query_params
      uri = URI("https://upload.twitter.com/1.1/media/upload.json?media_type=video/mp4")
      request = @request_builder.build(@authenticator, :post, uri)

      assert_equal "media_type=video%2Fmp4", request.uri.query
    end
  end
end
