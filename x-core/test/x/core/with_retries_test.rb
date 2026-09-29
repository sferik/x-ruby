# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A request that is safe to send again is sent again after any failure of the API or of the network
  class WithRetriesTest < Minitest::Test
    cover "X::Core.with_retries"

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

    def test_rejects_a_maximum_that_is_not_a_count
      error = assert_raises(ArgumentError) { Core.with_retries(max_retries: -1) { :done } }

      assert_equal "max_retries must be an Integer of at least 0, not -1", error.message
    end

    private

    # Run the block with the retries of X::Core.with_retries, collecting their waits, with no share taken off them
    def with_retries(**options, &)
      sleeps = @sleeps
      build = Core::RetryHandler.method(:new)
      without_sleeping = lambda do |**settings|
        build.call(**settings).tap do |handler|
          handler.define_singleton_method(:rand) { 0.0 }
          handler.define_singleton_method(:sleep) { |seconds| sleeps << seconds }
        end
      end
      Core::RetryHandler.stub(:new, without_sleeping) { Core.with_retries(**options, &) }
    end

    # Raise the given error, counting the attempt it ends
    def fail_with(error_class, cause = nil)
      @attempts += 1
      raise error_class, "boom", cause: cause if error_class.equal?(NetworkError)

      raise error_class.new(http_response: Net::HTTPResponse.new("1.1", {ServiceUnavailable => "503", BadRequest => "400"}.fetch(error_class), "Boom"))
    end
  end
end
