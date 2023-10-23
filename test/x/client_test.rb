require_relative "../test_helper"
require "hashie"

module X
  # Tests for X::Client class
  class ClientTest < Minitest::Test
    cover Client

    def setup
      @client = client
    end

    def test_initialize_oauth_credentials
      assert_equal TEST_API_KEY, @client.api_key
      assert_equal TEST_API_KEY_SECRET, @client.api_key_secret
      assert_equal TEST_ACCESS_TOKEN, @client.access_token
      assert_equal TEST_ACCESS_TOKEN_SECRET, @client.access_token_secret
    end

    def test_initialize_redirect_handler
      redirect_handler = @client.instance_variable_get(:@redirect_handler)

      assert_equal @client.instance_variable_get(:@authenticator), redirect_handler.authenticator
      assert_equal @client.instance_variable_get(:@connection), redirect_handler.connection
      assert_equal @client.instance_variable_get(:@request_builder), redirect_handler.request_builder
    end

    oauth_credentials.each_key do |missing_credential|
      define_method("test_missing_#{missing_credential}") do
        client = Client.new(**oauth_credentials.except(missing_credential))

        assert_instance_of Authenticator, client.instance_variable_get(:@authenticator)
      end
    end

    def test_bearer_token_authentication_request
      @bearer_token_client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .with(headers: {"Authorization" => /Bearer #{TEST_BEARER_TOKEN}/o})
      @bearer_token_client.get("tweets")

      assert_requested :get, "https://api.twitter.com/2/tweets"
    end

    def test_default_connection_options
      assert_equal Connection::DEFAULT_OPEN_TIMEOUT, @client.open_timeout
      assert_equal Connection::DEFAULT_READ_TIMEOUT, @client.read_timeout
      assert_equal Connection::DEFAULT_WRITE_TIMEOUT, @client.write_timeout
    end

    def test_initialize_connection_options
      @client = Client.new(**oauth_credentials, open_timeout: 0, read_timeout: 0, write_timeout: 0,
        debug_output: $stderr, proxy_url: "https://user:pass@proxy.com:42")

      assert_predicate @client.open_timeout, :zero?
      assert_predicate @client.read_timeout, :zero?
      assert_predicate @client.write_timeout, :zero?
      assert_equal $stderr, @client.debug_output
      assert_equal "https://user:pass@proxy.com:42", @client.proxy_url
    end

    def test_overwrite_defaults
      @client = Client.new(**oauth_credentials, base_url: "https://api.twitter.com/1.1/", max_redirects: 0,
        object_class: Hashie::Mash, array_class: Set)

      assert_equal "https://api.twitter.com/1.1/", @client.base_url
      assert_predicate @client.max_redirects, :zero?
      assert_equal Hashie::Mash, @client.object_class
      assert_equal Set, @client.array_class
    end

    RequestBuilder::HTTP_METHODS.each_key do |http_method|
      define_method("test_#{http_method}_request") do
        stub_request(http_method, "https://api.twitter.com/2/tweets")
        @client.public_send(http_method, "tweets")

        assert_requested http_method, "https://api.twitter.com/2/tweets"
      end

      define_method("test_#{http_method}_request_with_headers") do
        headers = {"User-Agent" => "Custom User Agent"}
        stub_request(http_method, "https://api.twitter.com/2/tweets")
        @client.public_send(http_method, "tweets", headers: headers)

        assert_requested http_method, "https://api.twitter.com/2/tweets", headers: headers
      end
    end

    [301, 302].each do |status|
      define_method("test_follows_#{status}_redirect") do
        stub_request(:get, "https://api.twitter.com/old_endpoint")
          .to_return(status: 301, headers: {"Location" => "https://api.twitter.com/new_endpoint"})
        stub_request(:get, "https://api.twitter.com/new_endpoint")
        @client.get("/old_endpoint")

        assert_requested :get, "https://api.twitter.com/new_endpoint"
      end
    end

    {307 => :post, 308 => :put}.each do |status, http_method|
      define_method("test_follows_#{status}_redirect") do
        stub_request(http_method, "https://api.twitter.com/temporary_redirect")
          .to_return(status: 307, headers: {"Location" => "https://api.twitter.com/new_endpoint"})
        body = {key: "value"}.to_json
        stub_request(http_method, "https://api.twitter.com/new_endpoint")
          .with(body: body)
        @client.public_send(http_method, "/temporary_redirect", body)

        assert_requested http_method, "https://api.twitter.com/new_endpoint", body: body
      end
    end

    def test_avoids_infinite_redirect_loop
      stub_request(:get, "https://api.twitter.com/infinite_loop")
        .to_return(status: 302, headers: {"Location" => "https://api.twitter.com/infinite_loop"})

      assert_raises TooManyRedirects do
        @client.get("/infinite_loop")
      end
    end
  end
end
