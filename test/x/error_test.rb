require_relative "../test_helper"

module X
  # Tests for errors
  class ErrorsTest < Minitest::Test
    cover Client

    def setup
      @client = client
    end

    ResponseHandler::ERROR_CLASSES.each do |status, error_class|
      define_method("test_#{error_class.name.split("::").last.downcase}_error") do
        stub_request(:get, "https://api.twitter.com/2/tweets").to_return(status: status)

        assert_raises error_class do
          @client.get("tweets")
        end
      end
    end

    Connection::NETWORK_ERRORS.each do |error_class|
      define_method("test_#{error_class.name.split("::").last.downcase}_error") do
        stub_request(:get, "https://api.twitter.com/2/tweets").to_raise(error_class)

        assert_raises NetworkError do
          @client.get("tweets")
        end
      end
    end

    def test_missing_credentials
      assert_raises(ArgumentError) { Client.new(**oauth_credentials.except(:api_key)) }
      assert_raises(ArgumentError) { Client.new(**oauth_credentials.except(:api_key_secret)) }
      assert_raises(ArgumentError) { Client.new(**oauth_credentials.except(:access_token)) }
      assert_raises(ArgumentError) { Client.new(**oauth_credentials.except(:access_token_secret)) }
    end

    def test_missing_credentials_message
      exception = assert_raises(ArgumentError) { Client.new }
      error_message = "Client must be initialized with either a bearer_token or " \
                      "an api_key, api_key_secret, access_token, and access_token_secret"

      assert_equal error_message, exception.message
    end

    def test_rate_limit
      headers = {"x-rate-limit-limit" => "40000", "x-rate-limit-remaining" => "39999"}
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .to_return(status: 429, headers: headers)

      begin
        @client.get("tweets")
      rescue TooManyRequests => e
        assert_equal 40_000, e.limit
        assert_equal 39_999, e.remaining
      end
    end

    def test_rate_limit_reset_at
      Time.stub :now, Time.utc(1983, 11, 24) do
        reset_time = Time.now.to_i + 900
        headers = {"x-rate-limit-reset" => reset_time.to_s}
        stub_request(:get, "https://api.twitter.com/2/tweets").to_return(status: 429, headers: headers)

        begin
          @client.get("tweets")
        rescue TooManyRequests => e
          assert_equal Time.at(reset_time), e.reset_at
        end
      end
    end

    def test_rate_limit_reset_in
      Time.stub :now, Time.utc(1983, 11, 24) do
        reset_time = Time.now.to_i + 900
        headers = {"x-rate-limit-reset" => reset_time.to_s}
        stub_request(:get, "https://api.twitter.com/2/tweets").to_return(status: 429, headers: headers)

        begin
          @client.get("tweets")
        rescue TooManyRequests => e
          assert_equal 900, e.reset_in
        end
      end
    end

    def test_rate_limit_reset_is_not_negative
      Time.stub :now, Time.utc(1983, 11, 24) do
        reset_time = Time.now.to_i - 1
        headers = {"content-type" => "application/json", "x-rate-limit-reset" => reset_time.to_s}
        stub_request(:get, "https://api.twitter.com/2/tweets").to_return(status: 429, headers: headers, body: "{}")

        begin
          @client.get("tweets")
        rescue TooManyRequests => e
          assert_equal 0, e.reset_in
        end
      end
    end

    def test_unexpected_response
      stub_request(:get, "https://api.twitter.com/2/tweets").to_return(status: 600)

      assert_raises Error do
        @client.get("tweets")
      end
    end

    def test_problem_json
      body = {error: "problem"}.to_json
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .to_return(status: 400, headers: {"content-type" => "application/problem+json"}, body: body)

      begin
        @client.get("tweets")
      rescue BadRequest => e
        assert_equal "problem", e.message
      end
    end
  end
end
