require "test_helper"

class ClientTest < Minitest::Test
  def setup
    @bearer_token = "TEST_BEARER_TOKEN"
    @api_key = "TEST_API_KEY"
    @api_key_secret = "TEST_API_KEY_SECRET"
    @access_token = "TEST_ACCESS_TOKEN"
    @access_token_secret = "TEST_ACCESS_TOKEN_SECRET"

    @client_bearer = X::Client.new(bearer_token: @bearer_token)
    @client_oauth = X::Client.new(api_key: @api_key, api_key_secret: @api_key_secret, access_token: @access_token,
                                  access_token_secret: @access_token_secret)
  end

  def test_bearer_token_get_request_success
    stub_bearer_request("tweets", :get, 200)

    response = @client_bearer.get("tweets")

    assert_instance_of Hash, response
    assert_requested :get, "https://api.twitter.com/2/tweets"
  end

  def test_bearer_token_get_request_failure
    stub_bearer_request("invalid_endpoint", :get, 404)

    assert_raises StandardError do
      @client_bearer.get("invalid_endpoint")
    end
  end

  def test_oauth_get_request_success
    stub_oauth_request("tweets", :get, 200)

    response = @client_oauth.get("tweets")

    assert_instance_of Hash, response
    assert_requested :get, "https://api.twitter.com/2/tweets"
  end

  def test_oauth_get_request_failure
    stub_oauth_request("invalid_endpoint", :get, 404)

    assert_raises StandardError do
      @client_oauth.get("invalid_endpoint")
    end
  end

  def test_post_request_success
    stub_oauth_request("tweets", :post, 200)

    body = '{"text":"Hello, World!"}'
    response = @client_oauth.post("tweets", body)

    assert_instance_of Hash, response
    assert_requested :post, "https://api.twitter.com/2/tweets"
  end

  def test_put_request_success
    stub_oauth_request("tweets/123", :put, 200)

    body = '{"text":"Updated tweet!"}'
    response = @client_oauth.put("tweets/123", body)

    assert_instance_of Hash, response
    assert_requested :put, "https://api.twitter.com/2/tweets/123"
  end

  def test_delete_request_success
    stub_oauth_request("tweets/123", :delete, 200)

    response = @client_oauth.delete("tweets/123")

    assert_instance_of Hash, response
    assert_requested :delete, "https://api.twitter.com/2/tweets/123"
  end

  def test_missing_credentials
    assert_raises ArgumentError do
      X::Client.new
    end
  end
end
