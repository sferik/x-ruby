# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RetryHandlerNetworkTest < Minitest::Test
    cover Core.const_get(:RetryHandler)

    def setup
      @sleeps = []
      @attempts = 0
    end

    def test_sends_a_request_again_that_timed_out_opening_its_connection
      assert_raises(NetworkError) { handle(Core.const_get(:RetryHandler).new(max_retries: 1)) { fail_with(NetworkError, cause: Net::OpenTimeout.new) } }
      assert_equal [2, [1]], [@attempts, @sleeps]
    end

    def test_sends_a_request_again_to_a_host_that_could_not_be_resolved
      assert_raises(NetworkError) { handle(Core.const_get(:RetryHandler).new(max_retries: 1)) { fail_with(NetworkError, cause: Socket::ResolutionError.new("getaddrinfo: nodename nor servname provided")) } }
      assert_equal [2, [1]], [@attempts, @sleeps]
    end

    def test_sends_a_request_again_to_a_host_that_could_not_be_reached
      [Errno::EHOSTUNREACH, Errno::ENETUNREACH].each do |error_class|
        @attempts = 0
        assert_raises(NetworkError) { handle(Core.const_get(:RetryHandler).new(max_retries: 1)) { fail_with(NetworkError, cause: error_class.new) } }
        assert_equal 2, @attempts
      end
    end

    def test_raises_at_once_for_a_request_that_timed_out_reading_its_answer
      assert_raises(NetworkError) { handle(Core.const_get(:RetryHandler).new(max_retries: 2)) { fail_with(NetworkError, cause: Net::ReadTimeout.new) } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_raises_at_once_for_a_request_whose_connection_dropped_once_it_was_sent
      assert_raises(NetworkError) { handle(Core.const_get(:RetryHandler).new(max_retries: 2)) { fail_with(NetworkError, cause: Errno::ECONNRESET.new) } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_raises_at_once_for_a_network_error_with_no_cause
      assert_raises(NetworkError) { handle(Core.const_get(:RetryHandler).new(max_retries: 2)) { fail_with(NetworkError, cause: nil) } }
      assert_equal [1, []], [@attempts, @sleeps]
    end

    def test_sends_a_request_again_that_timed_out_reading_its_answer_when_asked_to
      assert_raises(NetworkError) do
        handle(Core.const_get(:RetryHandler).new(max_retries: 2), resend_unanswered: true) { fail_with(NetworkError, cause: Net::ReadTimeout.new) }
      end
      assert_equal [3, [1, 2]], [@attempts, @sleeps]
    end

    def test_raises_at_once_for_a_request_that_is_not_idempotent_even_when_asked_to_resend_it
      assert_raises(NetworkError) do
        handle(Core.const_get(:RetryHandler).new(max_retries: 2), idempotent: false, resend_unanswered: true) { fail_with(NetworkError, cause: Net::ReadTimeout.new) }
      end
      assert_equal [1, []], [@attempts, @sleeps]
    end

    private

    # Run the block, collecting the waits, with no share of each one taken off
    def handle(handler, idempotent: true, **options, &)
      handler.stub(:rand, 0.0) do
        handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(idempotent:, **options, &) }
      end
    end

    # Raise a NetworkError with the given cause, counting the attempt it ends
    def fail_with(error_class, cause:)
      @attempts += 1
      raise error_class, "boom", cause:
    end
  end
end
