require_relative "../test_helper"
require "hashie"

module X
  # Tests for X::Client class
  class ClientTest < Minitest::Test
    def setup
      @client = client
      @bearer_token_client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    %i[get post put delete].each do |http_method|
      define_method("test_#{http_method}_oauth_request_success") do
        stub_request(http_method, "https://api.twitter.com/2/tweets")
          .with(headers: {"Authorization" => /OAuth/})
          .to_return(status: 200, headers: {"content-type" => "application/json"}, body: "{}")

        response = @client.public_send(http_method, "tweets")

        assert_instance_of Hash, response
        assert_requested http_method, "https://api.twitter.com/2/tweets"
      end

      define_method("test_#{http_method}_bearer_token_request_success") do
        stub_request(http_method, "https://api.twitter.com/2/tweets")
          .with(headers: {"Authorization" => /Bearer/})
          .to_return(status: 200, headers: {"content-type" => "application/json"}, body: "{}")

        response = @bearer_token_client.public_send(http_method, "tweets")

        assert_instance_of Hash, response
        assert_requested http_method, "https://api.twitter.com/2/tweets"
      end
    end

    def test_bearer_token
      assert_equal TEST_BEARER_TOKEN, @bearer_token_client.bearer_token
    end

    def test_set_bearer_token
      @bearer_token_client.bearer_token = "xyz"

      assert_equal "xyz", @bearer_token_client.bearer_token
    end

    def test_api_key
      assert_equal TEST_API_KEY, @client.api_key
      assert_equal TEST_API_KEY_SECRET, @client.api_key_secret
    end

    def test_set_api_key
      @client.api_key = "abc"
      @client.api_key_secret = "def"

      assert_equal "abc", @client.api_key
      assert_equal "def", @client.api_key_secret
    end

    def test_access_token
      assert_equal TEST_ACCESS_TOKEN, @client.access_token
      assert_equal TEST_ACCESS_TOKEN_SECRET, @client.access_token_secret
    end

    def test_set_access_token
      @client.access_token = "abc"
      @client.access_token_secret = "def"

      assert_equal "abc", @client.access_token
      assert_equal "def", @client.access_token_secret
    end

    def test_default_base_uri
      assert_equal URI.parse(Connection::DEFAULT_BASE_URL), @client.base_uri
    end

    def test_set_base_uri
      uri = URI("https://example.com")
      @client.base_uri = uri

      assert_equal uri, @client.base_uri
    end

    def test_default_user_agent
      assert_equal RequestBuilder::DEFAULT_USER_AGENT, @client.user_agent
    end

    def test_set_user_agent
      @client.user_agent = "Custom User Agent"

      assert_equal "Custom User Agent", @client.user_agent
    end

    def test_default_timeouts
      assert_equal Connection::DEFAULT_OPEN_TIMEOUT, @client.open_timeout
      assert_equal Connection::DEFAULT_READ_TIMEOUT, @client.read_timeout
      assert_equal Connection::DEFAULT_WRITE_TIMEOUT, @client.write_timeout
    end

    def test_set_timeouts
      @client.open_timeout = 10
      @client.read_timeout = 10
      @client.write_timeout = 10

      assert_equal 10, @client.open_timeout
      assert_equal 10, @client.read_timeout
      assert_equal 10, @client.write_timeout
    end

    def test_default_debug_output
      assert_nil @client.debug_output
    end

    def test_set_debug_output
      @client.debug_output = $stderr

      assert_equal $stderr, @client.debug_output
    end

    def test_default_object_class
      assert_equal ResponseHandler::DEFAULT_OBJECT_CLASS, @client.object_class
    end

    def test_set_object_class
      @client.object_class = Hashie::Mash

      assert_equal Hashie::Mash, @client.object_class
    end

    def test_default_array_class
      assert_equal ResponseHandler::DEFAULT_ARRAY_CLASS, @client.array_class
    end

    def test_set_array_class
      @client.array_class = Set

      assert_equal Set, @client.array_class
    end
  end
end
