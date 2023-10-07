require_relative "../test_helper"

module X
  # Tests for X::RequestBuilder class
  class RequestBuilderTest < Minitest::Test
    def setup
      @authenticator = BearerTokenAuthenticator.new(TEST_BEARER_TOKEN)
      @request_builder = RequestBuilder.new
    end

    def test_configuration
      assert_instance_of Hash, @request_builder.configuration
    end

    def test_uri_query_params_are_escaped
      uri = URI("https://upload.twitter.com/1.1/media/upload.json?media_type=video/mp4")
      request = @request_builder.build(@authenticator, :post, uri)

      assert_equal "media_type=video%2Fmp4", request.uri.query
    end
  end
end
