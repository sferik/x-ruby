require "test_helper"

class ErrorTest < Minitest::Test
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

  def test_bearer_token_get_request_failure
    stub_bearer_request(:get, "invalid_endpoint", 404)

    assert_raises StandardError do
      @client_bearer.get("invalid_endpoint")
    end
  end

  def test_oauth_get_request_failure
    stub_oauth_request(:get, "invalid_endpoint", 404)

    assert_raises StandardError do
      @client_oauth.get("invalid_endpoint")
    end
  end

  def test_bad_request
    stub_oauth_request(:get, "tweets", 400)

    assert_raises X::BadRequestError do
      @client_oauth.get("tweets")
    end
  end

  def test_unauthorized_request
    stub_oauth_request(:get, "tweets", 401)

    assert_raises X::AuthenticationError do
      @client_oauth.get("tweets")
    end
  end

  def test_forbidden_request
    stub_oauth_request(:get, "tweets", 403)

    assert_raises X::ForbiddenError do
      @client_oauth.get("tweets")
    end
  end

  def test_not_found_request
    stub_oauth_request(:get, "tweets", 404)

    assert_raises X::NotFoundError do
      @client_oauth.get("tweets")
    end
  end

  def test_too_many_requests
    stub_oauth_request(:get, "tweets", 429)

    assert_raises X::TooManyRequestsError do
      @client_oauth.get("tweets")
    end
  end

  def test_server_error
    stub_oauth_request(:get, "tweets", 500)

    assert_raises X::ServerError do
      @client_oauth.get("tweets")
    end
  end

  def test_service_unavailable_error
    stub_oauth_request(:get, "tweets", 503)

    assert_raises X::ServiceUnavailableError do
      @client_oauth.get("tweets")
    end
  end

  def test_unexpected_response
    stub_oauth_request(:get, "tweets", 600)

    assert_raises X::Error do
      @client_oauth.get("tweets")
    end
  end
end
