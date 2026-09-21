# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RetryHandlerTest < Minitest::Test
    cover Core::RetryHandler

    def setup
      @sleeps = []
      @attempts = 0
    end

    def test_defaults_to_retrying_nothing
      assert_equal 0, Core::RetryHandler.new.max_retries
    end

    def test_returns_what_the_block_returns
      assert_equal :done, handle(Core::RetryHandler.new) { :done }
    end

    def test_retries_nothing_by_default
      assert_raises(NetworkError) { handle(Core::RetryHandler.new) { fail_with(NetworkError) } }
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

    private

    # Run the block, collecting the waits, with the random share of each one fixed
    def handle(handler, idempotent: true, random: 0.0, &)
      handler.stub(:rand, random) do
        handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(idempotent:, &) }
      end
    end

    # Raise the given error, counting the attempt it ends
    def fail_with(error_class)
      @attempts += 1
      raise error_class, "boom" if error_class.equal?(NetworkError)

      raise error_class.new(http_response: Net::HTTPResponse.new("1.1", status_of(error_class), "Boom"))
    end

    def status_of(error_class)
      {ServiceUnavailable => "503", InternalServerError => "500", NotFound => "404"}.fetch(error_class)
    end
  end
end
