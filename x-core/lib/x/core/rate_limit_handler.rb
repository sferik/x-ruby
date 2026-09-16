require_relative "errors/too_many_requests"

module X
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
    # Seconds to wait before the first retry of a request refused without a reset time, doubled for each retry after
    UNREPORTED_RESET_WAIT = 60

    # The maximum number of times to retry a request refused for a rate limit
    # @api private
    # @return [Integer] the maximum number of retries
    # @example Get or set the maximum retries
    #   handler.max_rate_limit_retries = 3
    attr_accessor :max_rate_limit_retries

    # The maximum number of seconds to wait for a rate limit to reset before retrying
    # @api private
    # @return [Integer] the maximum wait in seconds
    # @example Get or set the maximum wait
    #   handler.max_rate_limit_wait = 60
    attr_accessor :max_rate_limit_wait

    # Initialize a new rate limit handler
    #
    # @api private
    # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit
    # @param max_rate_limit_wait [Integer] the maximum number of seconds to wait for a rate limit to reset
    # @return [RateLimitHandler] a new instance
    # @example Create a rate limit handler
    #   handler = X::RateLimitHandler.new(max_rate_limit_retries: 3)
    def initialize(max_rate_limit_retries: DEFAULT_MAX_RETRIES, max_rate_limit_wait: DEFAULT_MAX_WAIT)
      @max_rate_limit_retries = max_rate_limit_retries
      @max_rate_limit_wait = max_rate_limit_wait
    end

    # Run a request, running it again after a rate limit resets
    #
    # A request is retried while retries remain and the limit resets within the maximum wait; otherwise the
    # error is raised. A response that does not say when its limit resets waits a minute before the first retry,
    # doubling the wait for each retry after, as X recommends. The block must build its request anew each time,
    # so that each attempt is signed afresh.
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
    # @api private
    # @param error [TooManyRequests] the error the request raised
    # @param retries [Integer] the number of the retry, counting from one
    # @return [Integer] the seconds until the rate limit resets
    # @raise [TooManyRequests] the error being rescued, if no retries remain or the limit resets too late
    def wait_before_retry(error, retries)
      raise if retries > max_rate_limit_retries

      wait = error.rate_limit ? error.retry_after : UNREPORTED_RESET_WAIT << (retries - 1)
      raise if wait > max_rate_limit_wait

      wait
    end
  end
end
