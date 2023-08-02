require "test_helper"

class ClientTest < Minitest::Test
  def test_bearer_token_get_request_success
    stub_bearer_request(:get, "tweets", 200)

    response = client_bearer.get("tweets")

    assert_instance_of Hash, response
    assert_requested :get, "https://api.twitter.com/2/tweets"
  end

  def test_oauth_get_request_success
    stub_oauth_request(:get, "tweets", 200)

    response = client_oauth.get("tweets")

    assert_instance_of Hash, response
    assert_requested :get, "https://api.twitter.com/2/tweets"
  end

  def test_post_request_success
    stub_oauth_request(:post, "tweets", 200)

    body = '{"text":"Hello, World!"}'
    response = client_oauth.post("tweets", body)

    assert_instance_of Hash, response
    assert_requested :post, "https://api.twitter.com/2/tweets"
  end

  def test_put_request_success
    stub_oauth_request(:put, "tweets/123", 200)

    body = '{"text":"Updated tweet!"}'
    response = client_oauth.put("tweets/123", body)

    assert_instance_of Hash, response
    assert_requested :put, "https://api.twitter.com/2/tweets/123"
  end

  def test_delete_request_success
    stub_oauth_request(:delete, "tweets/123", 200)

    response = client_oauth.delete("tweets/123")

    assert_instance_of Hash, response
    assert_requested :delete, "https://api.twitter.com/2/tweets/123"
  end

  def test_missing_credentials
    assert_raises ArgumentError do
      X::Client.new
    end
  end

  def test_bearer_token_get_request_failure
    stub_bearer_request(:get, "invalid_endpoint", 404)

    assert_raises StandardError do
      client_bearer.get("invalid_endpoint")
    end
  end

  def test_oauth_get_request_failure
    stub_oauth_request(:get, "invalid_endpoint", 404)

    assert_raises StandardError do
      client_oauth.get("invalid_endpoint")
    end
  end

  def test_bad_request
    stub_oauth_request(:get, "tweets", 400)

    assert_raises X::BadRequestError do
      client_oauth.get("tweets")
    end
  end

  def test_unauthorized_request
    stub_oauth_request(:get, "tweets", 401)

    assert_raises X::AuthenticationError do
      client_oauth.get("tweets")
    end
  end

  def test_forbidden_request
    stub_oauth_request(:get, "tweets", 403)

    assert_raises X::ForbiddenError do
      client_oauth.get("tweets")
    end
  end

  def test_not_found_request
    stub_oauth_request(:get, "tweets", 404)

    assert_raises X::NotFoundError do
      client_oauth.get("tweets")
    end
  end

  def test_too_many_requests
    stub_oauth_request(:get, "tweets", 429)

    assert_raises X::TooManyRequestsError do
      client_oauth.get("tweets")
    end
  end

  def test_server_error
    stub_oauth_request(:get, "tweets", 500)

    assert_raises X::ServerError do
      client_oauth.get("tweets")
    end
  end

  def test_service_unavailable_error
    stub_oauth_request(:get, "tweets", 503)

    assert_raises X::ServiceUnavailableError do
      client_oauth.get("tweets")
    end
  end

  def test_unexpected_response
    stub_oauth_request(:get, "tweets", 600)

    assert_raises X::Error do
      client_oauth.get("tweets")
    end
  end

  def test_bearer_token
    assert_equal "TEST_BEARER_TOKEN", client_bearer.bearer_token
  end

  def test_set_bearer_token
    client = client_oauth
    assert_nil client.bearer_token
    refute client.instance_variable_get(:@http_request).instance_variable_get(:@use_bearer_token)

    client.bearer_token = "TEST_BEARER_TOKEN"
    assert_equal "TEST_BEARER_TOKEN", client.bearer_token
    assert client.instance_variable_get(:@http_request).instance_variable_get(:@use_bearer_token)
  end

  def test_api_key
    assert_equal "TEST_API_KEY", client_oauth.api_key
  end

  def test_set_api_key
    client = client_oauth
    client.api_key = "abc"
    assert_equal "abc", client.api_key
  end

  def test_api_key_secret
    assert_equal "TEST_API_KEY_SECRET", client_oauth.api_key_secret
  end

  def test_set_api_key_secret
    client = client_oauth
    client.api_key_secret = "xyz"
    assert_equal "xyz", client.api_key_secret
  end

  def test_access_token
    assert_equal "TEST_ACCESS_TOKEN", client_oauth.access_token
  end

  def test_set_access_token
    client = client_oauth
    client.access_token = "abc"
    assert_equal "abc", client.access_token
  end

  def test_access_token_secret
    assert_equal "TEST_ACCESS_TOKEN_SECRET", client_oauth.access_token_secret
  end

  def test_set_access_token_secret
    client = client_oauth
    client.access_token_secret = "xyz"
    assert_equal "xyz", client.access_token_secret
  end

  def test_default_base_url
    assert_equal X::Client::DEFAULT_BASE_URL, client_oauth.base_url
  end

  def test_set_base_url
    client = client_oauth
    client.base_url = "https://example.com"
    assert_equal "https://example.com", client.base_url
  end

  def test_default_user_agent
    assert_equal X::Client::DEFAULT_USER_AGENT, client_oauth.user_agent
  end

  def test_set_user_agent
    client = client_oauth
    client.user_agent = "Custom User Agent"
    assert_equal "Custom User Agent", client.user_agent
  end
end
