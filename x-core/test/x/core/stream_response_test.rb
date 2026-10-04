# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The response Client#get_stream passes its block is x-core's own, which reads the status, headers, and rate limits
  # of the response of the transport, so that the block reads none of them from Net::HTTP
  class StreamResponseTest < Minitest::Test
    cover_client
    cover StreamResponse

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"
    RATE_LIMIT = {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "49", "x-rate-limit-reset" => "438480000"}.freeze
    APP_LIMIT = {"x-app-limit-24hour-limit" => "500", "x-app-limit-24hour-remaining" => "7", "x-app-limit-24hour-reset" => "438480000"}.freeze

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_the_status_is_an_integer
      stub_request(:get, STREAM_URL).to_return(status: 206)

      assert_equal 206, stream(&:status)
    end

    def test_the_uri_is_that_of_the_request
      stub_request(:get, "#{STREAM_URL}?expansions=author_id")

      assert_equal URI("#{STREAM_URL}?expansions=author_id"), @client.get_stream("tweets/sample/stream", params: {expansions: "author_id"}, &:uri)
    end

    def test_the_headers_are_lowercase_and_frozen
      stub_request(:get, STREAM_URL).to_return(headers: {"X-Response-Time" => "12", "Content-Type" => "application/json"})
      headers = stream(&:headers)

      assert_equal({"x-response-time" => "12", "content-type" => "application/json"}, headers)
      assert_predicate headers, :frozen?
    end

    def test_the_rate_limits_are_those_the_response_reports
      stub_request(:get, STREAM_URL).to_return(headers: APP_LIMIT.merge(RATE_LIMIT))

      assert_equal [["rate-limit", 49], ["app-limit-24hour", 7]], stream(&:rate_limits).map { |limit| [limit.type, limit.remaining] }
    end

    def test_the_rate_limit_is_the_15_minute_limit_of_the_endpoint
      stub_request(:get, STREAM_URL).to_return(headers: APP_LIMIT.merge(RATE_LIMIT))

      assert_equal ["rate-limit", 50, 49], stream { |response| [response.rate_limit.type, response.rate_limit.limit, response.rate_limit.remaining] }
    end

    def test_a_response_that_reports_no_15_minute_limit_has_none
      stub_request(:get, STREAM_URL).to_return(headers: APP_LIMIT)

      assert_equal [nil, 1], stream { |response| [response.rate_limit, response.rate_limits.size] }
    end

    def test_the_http_response_is_the_response_of_the_transport
      stub_request(:get, STREAM_URL)

      assert_equal [Net::HTTPOK, "200"], stream { |response| [response.http_response.class, response.http_response.code] }
    end

    def test_a_stream_response_is_built_by_x_core_alone
      assert_raises(NoMethodError) { StreamResponse.new(http_response: Net::HTTPOK.new("1.1", "200", "OK"), uri: URI(STREAM_URL)) }
    end

    private

    def stream(&) = @client.get_stream("tweets/sample/stream", &)
  end
end
