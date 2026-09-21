# frozen_string_literal: true

require_relative "errors/too_many_requests"

module X
  module Core
    # Retries requests the API refuses for a rate limit, waiting until the limit resets
    #
    # Internal to x-core: Client retries with it, and takes max_rate_limit_retries and max_rate_limit_wait.
    #
    # @api private
    class RateLimitHandler
      # Default maximum number of retries, which retries nothing
      DEFAULT_MAX_RETRIES = 0
      # Default maximum number of seconds to wait for a rate limit to reset, the length of a 15-minute window
      DEFAULT_MAX_WAIT = 900
      # Seconds to wait before the first retry of a request refused without a Retry-After header or a reset time,
      # doubled for each retry after
      UNREPORTED_RESET_WAIT = 60
      # The most seconds added at random to a wait, which keep apart the requests one reset releases
      RESET_JITTER = 5

      # The maximum number of times to retry a request refused for a rate limit
      # @api private
      # @return [Integer] the maximum number of retries
      # @example Get or set the maximum retries
      #   handler.max_rate_limit_retries = 3
      attr_reader :max_rate_limit_retries

      # The maximum number of seconds to wait for a rate limit to reset before retrying
      # @api private
      # @return [Integer] the maximum wait in seconds
      # @example Get or set the maximum wait
      #   handler.max_rate_limit_wait = 60
      attr_reader :max_rate_limit_wait

      # Initialize a new rate limit handler
      #
      # @api private
      # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit
      # @param max_rate_limit_wait [Integer] the maximum number of seconds to wait for a rate limit to reset
      # @return [RateLimitHandler] a new instance
      # @example Create a rate limit handler
      #   handler = X::Core::RateLimitHandler.new(max_rate_limit_retries: 3)
      def initialize(max_rate_limit_retries: DEFAULT_MAX_RETRIES, max_rate_limit_wait: DEFAULT_MAX_WAIT)
        @max_rate_limit_retries = max_rate_limit_retries
        @max_rate_limit_wait = max_rate_limit_wait
      end

      # Run a request, running it again after a rate limit resets
      #
      # A request is retried while retries remain and the wait the response asks for is within the maximum wait;
      # otherwise the error is raised. A response that asks for neither a wait nor a reset time waits a minute
      # before the first retry, doubling the wait for each retry after, as X recommends. The block must build its
      # request anew each time, so that each attempt is signed afresh.
      #
      # Every request of an app shares the app's limits, and so the time they reset, so a few seconds are added at
      # random to each wait, to keep the requests one reset releases from being sent again in one burst.
      #
      # @api private
      # @yield runs the request
      # @return [Object] what the block returns
      # @raise [TooManyRequests] if the request is refused once more than the retries allow, or for too long a wait
      # @example Retry a request
      #   handler.handle { client.get("users/me") }
      def handle
        retries = 0
        begin
          yield
        rescue TooManyRequests => e
          retries += 1
          sleep wait_before_retry(e, retries)
          retry
        end
      end

      private

      # The seconds to wait before a retry, raising the error if it may not retry
      #
      # The random share is added to the wait rather than taken off it, since a request sent before the limit
      # resets is refused again, and so it is not counted against the maximum wait, which is the longest reset a
      # request waits for.
      #
      # @api private
      # @param error [TooManyRequests] the error the request raised
      # @param retries [Integer] the number of the retry, counting from one
      # @return [Float] the seconds the response asks the request to wait, and a random share of RESET_JITTER
      # @raise [TooManyRequests] the error being rescued, if no retries remain or the wait is too long
      def wait_before_retry(error, retries)
        raise if retries > max_rate_limit_retries

        wait = error.retry_after || UNREPORTED_RESET_WAIT << (retries - 1)
        raise if wait > max_rate_limit_wait

        wait + (rand * RESET_JITTER)
      end
    end
  end
end
