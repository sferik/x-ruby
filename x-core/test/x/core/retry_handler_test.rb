# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RetryHandlerTest < Minitest::Test
    cover Core::RetryHandler

    def setup
      @sleeps = []
      @attempts = 0
    end

    def test_defaults_to_sending_a_request_twice_more
      assert_equal 2, Core::RetryHandler.new.max_retries
    end

    def test_returns_what_the_block_returns
      assert_equal :done, handle(Core::RetryHandler.new) { :done }
    end

    def test_sends_an_idempotent_request_twice_more_by_default
      assert_raises(NetworkError) { handle(Core::RetryHandler.new) { fail_with(NetworkError) } }
      assert_equal [3, [1, 2]], [@attempts, @sleeps]
    end

    def test_retries_nothing_once_retries_are_turned_off
      assert_raises(NetworkError) { handle(Core::RetryHandler.new(max_retries: 0)) { fail_with(NetworkError) } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_sends_an_idempotent_request_again_after_a_network_error
      result = handle(Core::RetryHandler.new(max_retries: 1)) { (@attempts < 1) ? fail_with(NetworkError) : @attempts += 1 }

      assert_equal [2, [1]], [result, @sleeps]
    end

    def test_sends_an_idempotent_request_again_after_the_api_fails_to_answer
      result = handle(Core::RetryHandler.new(max_retries: 1)) { (@attempts < 1) ? fail_with(ServiceUnavailable) : @attempts += 1 }

      assert_equal [2, [1]], [result, @sleeps]
    end

    def test_waits_a_second_and_doubles_the_wait_before_each_retry
      assert_raises(NetworkError) { handle(Core::RetryHandler.new(max_retries: 3)) { fail_with(NetworkError) } }
      assert_equal [4, [1, 2, 4]], [@attempts, @sleeps]
    end

    def test_takes_up_to_half_of_each_wait_off_at_random
      assert_raises(NetworkError) { handle(Core::RetryHandler.new(max_retries: 3), random: 1.0) { fail_with(NetworkError) } }
      assert_equal [4, [0.5, 1, 2]], [@attempts, @sleeps]
    end

    def test_takes_a_share_of_each_wait_off_in_proportion_to_the_random_number
      assert_raises(NetworkError) { handle(Core::RetryHandler.new(max_retries: 2), random: 0.5) { fail_with(NetworkError) } }
      assert_equal [3, [0.75, 1.5]], [@attempts, @sleeps]
    end

    def test_raises_the_error_once_the_retries_run_out
      assert_raises(InternalServerError) { handle(Core::RetryHandler.new(max_retries: 2)) { fail_with(InternalServerError) } }
      assert_equal [3, [1, 2]], [@attempts, @sleeps]
    end

    def test_raises_at_once_for_a_request_that_is_not_idempotent
      assert_raises(NetworkError) { handle(Core::RetryHandler.new(max_retries: 2), idempotent: false) { fail_with(NetworkError) } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_raises_at_once_for_a_failure_the_request_is_the_reason_for
      assert_raises(NotFound) { handle(Core::RetryHandler.new(max_retries: 2)) { fail_with(NotFound) } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_waits_as_long_as_the_response_asks
      assert_raises(ServiceUnavailable) { handle(Core::RetryHandler.new(max_retries: 2)) { fail_with(ServiceUnavailable, retry_after: "30") } }
      assert_equal [3, [30, 30]], [@attempts, @sleeps]
    end

    def test_waits_out_the_backoff_when_it_is_longer_than_the_wait_the_response_asks_for
      assert_raises(ServiceUnavailable) { handle(Core::RetryHandler.new(max_retries: 3)) { fail_with(ServiceUnavailable, retry_after: "3") } }
      assert_equal [4, [3, 3, 4]], [@attempts, @sleeps]
    end

    def test_waits_until_the_time_the_response_names
      Time.stub(:now, Time.utc(1983, 11, 24)) do
        assert_raises(ServiceUnavailable) { handle(Core::RetryHandler.new(max_retries: 1)) { fail_with(ServiceUnavailable, retry_after: (Time.now + 45).httpdate) } }
      end
      assert_equal [2, [45]], [@attempts, @sleeps]
    end

    def test_raises_at_once_for_a_response_that_asks_for_a_longer_wait_than_a_request_waits_out
      assert_raises(ServiceUnavailable) { handle(Core::RetryHandler.new(max_retries: 2)) { fail_with(ServiceUnavailable, retry_after: "61") } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_waits_out_the_longest_wait_a_response_may_ask_for
      assert_raises(ServiceUnavailable) { handle(Core::RetryHandler.new(max_retries: 1)) { fail_with(ServiceUnavailable, retry_after: "60") } }
      assert_equal [2, [60]], [@attempts, @sleeps]
    end

    def test_backs_off_after_a_response_that_asks_for_no_wait
      assert_raises(ServiceUnavailable) { handle(Core::RetryHandler.new(max_retries: 1)) { fail_with(ServiceUnavailable, retry_after: "whenever you like") } }
      assert_equal [2, [1]], [@attempts, @sleeps]
    end

    private

    # Run the block, collecting the waits, with the random share of each one fixed
    def handle(handler, idempotent: true, random: 0.0, &)
      handler.stub(:rand, random) do
        handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(idempotent:, &) }
      end
    end

    # Raise the given error, counting the attempt it ends
    def fail_with(error_class, retry_after: nil)
      @attempts += 1
      raise error_class, "boom" if error_class.equal?(NetworkError)

      response = Net::HTTPResponse.new("1.1", status_of(error_class), "Boom")
      response["retry-after"] = retry_after unless retry_after.nil?
      raise error_class.new(http_response: response)
    end

    def status_of(error_class)
      {ServiceUnavailable => "503", InternalServerError => "500", NotFound => "404"}.fetch(error_class)
    end
  end
end
