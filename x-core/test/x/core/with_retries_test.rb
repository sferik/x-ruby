# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A request that is safe to send again is sent again after any failure of the API or of the network
  class WithRetriesTest < Minitest::Test
    cover "X::Client#with_retries"
    cover "X::Core::ClientSettings#with_retries"

    def setup
      @sleeps = []
      @attempts = 0
    end

    def test_returns_what_the_block_returns
      assert_equal :done, with_retries { :done }
    end

    def test_sends_a_request_twice_more_by_default
      assert_raises(ServiceUnavailable) { with_retries { fail_with(ServiceUnavailable) } }
      assert_equal [3, [1, 2]], [@attempts, @sleeps]
    end

    def test_sends_a_request_again_as_often_as_it_is_told
      assert_raises(ServiceUnavailable) { with_retries(max_retries: 3) { fail_with(ServiceUnavailable) } }
      assert_equal [4, [1, 2, 4]], [@attempts, @sleeps]
    end

    def test_sends_a_request_again_after_it_timed_out_reading_its_answer
      assert_equal 2, with_retries(max_retries: 1) { (@attempts < 1) ? fail_with(NetworkError, Net::ReadTimeout.new) : @attempts += 1 }
      assert_equal [1], @sleeps
    end

    def test_raises_at_once_for_a_failure_the_request_is_the_reason_for
      assert_raises(BadRequest) { with_retries { fail_with(BadRequest) } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_counts_the_rate_limit_retries_of_a_request_across_the_attempts_it_sends_again
      stub_request(:post, "https://api.x.com/2/media/upload/1/append").to_return(refused, {status: 503}, refused, {status: 200})
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_rate_limit_retries: 1)
      rate_limits = internals(client).instance_variable_get(:@rate_limit_handler)
      rate_limits.define_singleton_method(:sleep) { |_| nil }

      assert_raises(TooManyRequests) { with_retries_of(client) { client.post("media/upload/1/append", "chunk") } }
      assert_requested :post, "https://api.x.com/2/media/upload/1/append", times: 3
    end

    private

    # Run the block with the retries of a client, collecting their waits, with no share taken off them
    def with_retries(**options, &) = with_retries_of(Client.new(**options), &)

    # Run the block with the retries of the client given, collecting their waits, with no share taken off them
    def with_retries_of(client, &)
      sleeps = @sleeps
      handler = internals(client).instance_variable_get(:@retry_handler)
      handler.define_singleton_method(:rand) { 0.0 }
      handler.define_singleton_method(:sleep) { |seconds| sleeps << seconds }
      client.with_retries(&)
    end

    def refused
      {status: 429, headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "0", "x-rate-limit-reset" => Time.now.to_i.to_s}}
    end

    # Raise the given error, counting the attempt it ends
    def fail_with(error_class, cause = nil)
      @attempts += 1
      raise error_class, "boom", cause: cause if error_class.equal?(NetworkError)

      raise error_class.new(http_response: Net::HTTPResponse.new("1.1", {ServiceUnavailable => "503", BadRequest => "400"}.fetch(error_class), "Boom"))
    end
  end
end
