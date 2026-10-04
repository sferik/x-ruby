# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A request that a server error sends again is not rate limited anew on each attempt: its retries for a rate limit
  # are counted across them, so max_rate_limit_retries bounds the retries of the request
  class ClientRateLimitRetriesAcrossAttemptsTest < Minitest::Test
    cover_client

    URL = "https://api.x.com/2/users/me"
    SUCCESS = {status: 200, body: '{"data":{"id":"1"}}', headers: {"Content-Type" => "application/json"}}.freeze
    UNAVAILABLE = {status: 503}.freeze
    INNER_URL = "https://api.x.com/2/tweets/1"
    TOKENS = {token_type: "bearer", access_token: "NEW", refresh_token: "NEW_REFRESH", expires_in: 7200}.to_json.freeze

    def setup
      @rate_limit_sleeps = []
    end

    def test_rate_limit_retries_are_counted_across_the_attempts_a_server_error_sends_again
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_rate_limit_retries: 1)
      stub_request(:get, URL).to_return(refused, UNAVAILABLE, refused, UNAVAILABLE, refused, SUCCESS)

      assert_raises(TooManyRequests) { without_sleeping(client) { client.get("users/me") } }
      assert_equal 1, @rate_limit_sleeps.size
      assert_requested :get, URL, times: 3
    end

    def test_a_request_within_its_rate_limit_retries_across_attempts_is_answered
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_rate_limit_retries: 2)
      stub_request(:get, URL).to_return(refused, UNAVAILABLE, refused, SUCCESS)

      assert_equal({"data" => {"id" => "1"}}, without_sleeping(client) { client.get("users/me") })
      assert_equal 2, @rate_limit_sleeps.size
    end

    def test_each_request_counts_its_rate_limit_retries_afresh
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_rate_limit_retries: 1)
      stub_request(:get, URL).to_return(refused, SUCCESS, refused, SUCCESS)

      2.times { without_sleeping(client) { client.get("users/me") } }

      assert_equal 2, @rate_limit_sleeps.size
      assert_nil Thread.current[:x_core_rate_limit_retries]
    end

    def test_a_request_on_response_sends_counts_its_own_rate_limit_retries
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_rate_limit_retries: 1, on_response: ->(response) { looked_up(client, response) })
      stub_request(:get, URL).to_return(refused, SUCCESS)
      stub_request(:get, INNER_URL).to_return(refused, SUCCESS)

      assert_equal 1, answered_with_waits(client)
    end

    def test_a_request_save_tokens_sends_counts_its_own_rate_limit_retries
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 5, max_rate_limit_retries: 1, save_tokens: ->(_) { client.get("tweets/1") })
      stub_request(:post, "https://api.x.com/2/oauth2/token").to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: TOKENS)
      stub_request(:get, INNER_URL).to_return(refused, SUCCESS)
      stub_request(:get, URL).to_return(refused, SUCCESS)

      assert_equal 1, answered_with_waits(client)
    end

    private

    # Look a post up after the lookup of the user is answered, as a hook of the client may
    def looked_up(client, response)
      client.get("tweets/1") if response.uri.path.end_with?("me") && response.status.eql?(200)
    end

    # Look the user up, and give the id of the user answered and the rate limit waits each request took apart
    def answered_with_waits(client)
      id = without_sleeping(client) { client.get("users/me") }.dig("data", "id").to_i

      assert_equal 2, @rate_limit_sleeps.size
      id
    end

    def refused
      {status: 429, headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => Time.now.to_i.to_s}}
    end

    # Collect the rate limit waits instead of taking them, and take no wait between the attempts of a server error
    def without_sleeping(client, &)
      rate_limits = internals(client).instance_variable_get(:@rate_limit_handler)
      retries = internals(client).instance_variable_get(:@retry_handler)
      retries.stub(:sleep, nil) do
        rate_limits.stub(:rand, 0.0) { rate_limits.stub(:sleep, ->(seconds) { @rate_limit_sleeps << seconds }, &) }
      end
    end
  end
end
