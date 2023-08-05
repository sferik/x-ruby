require "test_helper"

# Tests for X::Client class
class ClientTest < Minitest::Test
  def setup
    @client_bearer = client_bearer
    @client_oauth = client_oauth
  end

  # Define test cases for different HTTP methods using parameterized testing
  [
    [:get, "tweets"],
    [:post, "tweets", '{"text":"Hello, World!"}'],
    [:put, "tweets/123", '{"text":"Updated tweet!"}'],
    [:delete, "tweets/123"]
  ].each do |http_method, endpoint, body|
    define_method("test_#{http_method}_request_success") do
      stub_oauth_request(http_method, endpoint, 200)

      response = @client_oauth.public_send(http_method, endpoint, body)

      assert_instance_of Hash, response
      assert_requested http_method, "https://api.twitter.com/2/#{endpoint}"
    end
  end

  def test_bearer_token_get_request_success
    stub_bearer_request(:get, "tweets", 200)

    response = @client_bearer.get("tweets")

    assert_instance_of Hash, response
    assert_requested :get, "https://api.twitter.com/2/tweets"
  end

  def test_bearer_token
    assert_nil @client_oauth.bearer_token
    assert_equal TEST_BEARER_TOKEN, @client_bearer.bearer_token
  end

  def test_set_bearer_token
    @client_oauth.bearer_token = "abc"

    assert_equal "abc", @client_oauth.bearer_token
  end

  def test_api_key
    assert_equal TEST_API_KEY, @client_oauth.api_key
  end

  def test_set_api_key
    @client_oauth.api_key = "abc"

    assert_equal "abc", @client_oauth.api_key
  end

  def test_api_key_secret
    assert_equal TEST_API_KEY_SECRET, @client_oauth.api_key_secret
  end

  def test_set_api_key_secret
    @client_oauth.api_key_secret = "xyz"

    assert_equal "xyz", @client_oauth.api_key_secret
  end

  def test_access_token
    assert_equal TEST_ACCESS_TOKEN, @client_oauth.access_token
  end

  def test_set_access_token
    @client_oauth.access_token = "abc"

    assert_equal "abc", @client_oauth.access_token
  end

  def test_access_token_secret
    assert_equal TEST_ACCESS_TOKEN_SECRET, @client_oauth.access_token_secret
  end

  def test_set_access_token_secret
    @client_oauth.access_token_secret = "xyz"

    assert_equal "xyz", @client_oauth.access_token_secret
  end

  def test_default_base_url
    assert_equal URI.parse(X::Client::DEFAULT_BASE_URL), @client_oauth.base_url
  end

  def test_set_base_url
    url = URI("https://example.com")
    @client_oauth.base_url = url

    assert_equal url, @client_oauth.base_url
  end

  def test_default_user_agent
    assert_equal X::Client::DEFAULT_USER_AGENT, @client_oauth.user_agent
  end

  def test_set_user_agent
    @client_oauth.user_agent = "Custom User Agent"

    assert_equal "Custom User Agent", @client_oauth.user_agent
  end

  def test_default_read_timeout
    assert_equal X::Client::DEFAULT_READ_TIMEOUT, @client_oauth.read_timeout
  end

  def test_set_read_timeout
    @client_oauth.read_timeout = 10

    assert_equal 10, @client_oauth.read_timeout
  end
end
