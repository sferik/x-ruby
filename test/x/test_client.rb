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
end
