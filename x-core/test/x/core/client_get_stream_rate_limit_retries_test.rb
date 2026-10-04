# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream counts as a request of its own, so a request its block sends counts its rate limit retries afresh, even
  # when with_retries wraps the stream
  class ClientGetStreamRateLimitRetriesTest < Minitest::Test
    cover_client

    STREAM_URL = "https://api.x.com/2/tweets/search/stream"
    USER_URL = "https://api.x.com/2/users/me"

    def test_each_request_a_stream_block_sends_inside_with_retries_counts_its_own_rate_limit_retries
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_rate_limit_retries: 1)
      stub_request(:get, STREAM_URL).to_return(body: "1\n2\n3\n")
      stub_request(:get, USER_URL).to_return(*[refused, {status: 200, body: "{}"}] * 3)
      lookups = 0
      without_sleeping(client) do
        client.with_retries { client.get_stream("tweets/search/stream") { |response| response.read_body { |chunk| chunk.lines.each { lookups += 1 if client.get("users/me") } } } }
      end

      assert_equal 3, lookups
    end

    private

    def refused
      {status: 429, headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => Time.now.to_i.to_s}}
    end

    def without_sleeping(client, &)
      handler = internals(client).instance_variable_get(:@rate_limit_handler)
      handler.stub(:rand, 0.0) { handler.stub(:sleep, nil, &) }
    end
  end
end
