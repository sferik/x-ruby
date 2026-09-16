require "uri"
require_relative "../../test_helper"

module X
  class RequestBuilderTest < Minitest::Test
    cover RequestBuilder

    def setup
      @authenticator = OAuth1Authenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET,
        access_token: TEST_ACCESS_TOKEN, access_token_secret: TEST_ACCESS_TOKEN_SECRET)
      @request_builder = RequestBuilder.new
      @uri = URI("http://example.com")
    end

    def test_build_get_request
      expected = "OAuth oauth_consumer_key=\"TEST_API_KEY\", oauth_nonce=\"TEST_OAUTH_NONCE\", " \
                 "oauth_signature=\"YF2HnkQuY39Db8GywIJy%2BUfFxnc%3D\", oauth_signature_method=\"HMAC-SHA1\", " \
                 "oauth_timestamp=\"438480000\", oauth_token=\"TEST_ACCESS_TOKEN\", oauth_version=\"1.0\""
      with_fixed_oauth_params do
        request = @request_builder.build(http_method: :get, uri: @uri, authenticator: @authenticator)

        assert_equal "GET", request.method
        assert_equal @uri, request.uri
        assert_equal expected, request["Authorization"]
        assert_equal "application/json; charset=utf-8", request["Content-Type"]
      end
    end

    def test_build_post_request
      expected = "OAuth oauth_consumer_key=\"TEST_API_KEY\", oauth_nonce=\"TEST_OAUTH_NONCE\", " \
                 "oauth_signature=\"5TTQPQ7SqAxR74YSGbm%2FCmuts2I%3D\", oauth_signature_method=\"HMAC-SHA1\", " \
                 "oauth_timestamp=\"438480000\", oauth_token=\"TEST_ACCESS_TOKEN\", oauth_version=\"1.0\""

      with_fixed_oauth_params do
        request = @request_builder.build(http_method: :post, uri: @uri, body: "{}", authenticator: @authenticator)

        assert_equal "POST", request.method
        assert_equal @uri, request.uri
        assert_equal "{}", request.body
        assert_equal expected, request["Authorization"]
      end
    end

    def test_custom_headers
      request = @request_builder.build(http_method: :get, uri: @uri,
        headers: {"User-Agent" => "Custom User Agent"}, authenticator: @authenticator)

      assert_equal "Custom User Agent", request["User-Agent"]
    end

    def test_build_without_authenticator_parameter
      request = @request_builder.build(http_method: :get, uri: @uri)

      refute request.key?("Authorization")
    end

    def test_unsupported_http_method
      exception = assert_raises ArgumentError do
        @request_builder.build(http_method: :unsupported, uri: @uri, authenticator: @authenticator)
      end

      assert_equal "Unsupported HTTP method: unsupported", exception.message
    end

    def test_escape_query_params
      uri = "https://upload.twitter.com/1.1/media/upload.json?media_type=video/mp4"
      request = @request_builder.build(http_method: :post, uri:, authenticator: @authenticator)

      assert_equal "media_type=video%2Fmp4", request.uri.query
    end

    def test_escape_query_params_with_commas
      uri = "https://api.x.com/2/tweets/search/recent?query=%23ruby&expansions=author_id&user.fields=id,name,username"
      request = @request_builder.build(http_method: :post, uri:, authenticator: @authenticator)

      assert_equal "query=%23ruby&expansions=author_id&user.fields=id,name,username", request.uri.query
    end
  end
end
