require "test_helper"

# Tests for X::Error subclasses
class ErrorTest < Minitest::Test
  def test_missing_credentials
    assert_raises ArgumentError do
      X::Client.new
    end
  end

  def test_set_invalid_base_url
    client = client_oauth
    assert_raises ArgumentError do
      client.base_url = "ftp://ftp.example.com"
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

  def test_rate_limit
    stub_oauth_request(:get, "tweets", 429, { "x-rate-limit-limit" => "40000", "x-rate-limit-remaining" => "39999" })

    begin
      client_oauth.get("tweets")
    rescue X::TooManyRequestsError => e
      assert_equal 40_000, e.limit
      assert_equal 39_999, e.remaining
    end
  end

  def test_rate_limit_reset
    reset_time = Time.now.utc.to_i + 900
    stub_oauth_request(:get, "tweets", 429, { "x-rate-limit-reset" => reset_time.to_s })

    begin
      client_oauth.get("tweets")
    rescue X::TooManyRequestsError => e
      assert_equal Time.at(reset_time).utc, e.reset_at
      assert_equal 900, e.reset_in
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

  def test_errno_econnrefused
    stub_request(:get, "https://api.twitter.com/2/tweets").to_raise(Errno::ECONNREFUSED)

    assert_raises X::NetworkError do
      client_oauth.get("tweets")
    end
  end

  def test_net_read_timeout
    stub_request(:get, "https://api.twitter.com/2/tweets").to_raise(Net::ReadTimeout)

    assert_raises X::NetworkError do
      client_oauth.get("tweets")
    end
  end
end
