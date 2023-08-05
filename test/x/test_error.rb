require "test_helper"

# Tests for X::Error subclasses
class ErrorTest < Minitest::Test
  def setup
    @client_oauth = client_oauth
  end

  X::Client::ResponseHandler::ERROR_CLASSES.each do |status, error_class|
    define_method("test_#{error_class.name.split("::").last.downcase}_error") do
      stub_oauth_request(:get, "tweets", status)

      assert_raises error_class do
        @client_oauth.get("tweets")
      end
    end
  end

  X::Client::NETWORK_ERRORS.each do |error_class|
    define_method("test_#{error_class.name.split("::").last.downcase}_error") do
      stub_request(:get, "https://api.twitter.com/2/tweets").to_raise(error_class)

      assert_raises X::NetworkError do
        @client_oauth.get("tweets")
      end
    end
  end

  def test_missing_credentials
    assert_raises ArgumentError do
      X::Client.new
    end
  end

  def test_set_invalid_base_url
    assert_raises ArgumentError do
      @client_oauth.base_url = "ftp://ftp.example.com"
    end
  end

  def test_rate_limit
    stub_oauth_request(:get, "tweets", 429, {"x-rate-limit-limit" => "40000", "x-rate-limit-remaining" => "39999"})

    begin
      @client_oauth.get("tweets")
    rescue X::TooManyRequestsError => e
      assert_equal 40_000, e.limit
      assert_equal 39_999, e.remaining
    end
  end

  def test_rate_limit_reset
    reset_time = Time.now.utc.to_i + 900
    stub_oauth_request(:get, "tweets", 429, {"x-rate-limit-reset" => reset_time.to_s})

    begin
      @client_oauth.get("tweets")
    rescue X::TooManyRequestsError => e
      assert_equal Time.at(reset_time).utc, e.reset_at
      assert_equal 900, e.reset_in
    end
  end

  def test_unexpected_response
    stub_oauth_request(:get, "tweets", 600)

    assert_raises X::Error do
      client_oauth.get("tweets")
    end
  end
end
