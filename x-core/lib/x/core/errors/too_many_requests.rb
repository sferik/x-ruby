require_relative "client_error"
require_relative "../rate_limit"

module X
  # Error raised when rate limit is exceeded (HTTP 429)
  # @api public
  class TooManyRequests < ClientError
    # Get the most restrictive rate limit
    #
    # @api public
    # @return [RateLimit, nil] the rate limit with the latest reset time
    # @example Get the rate limit
    #   error.rate_limit
    def rate_limit
      rate_limits.max_by(&:reset_at)
    end

    # Get all rate limits from the response
    #
    # @api public
    # @return [Array<RateLimit>] the rate limits that are exhausted, among those the response reports in full
    # @example Get all rate limits
    #   error.rate_limits
    def rate_limits
      @rate_limits ||= RateLimit::TYPES.filter_map { |type| RateLimit.new(type:, response:) if RateLimit.reported?(type, response) }.select(&:exhausted?)
    end

    # Get the time when the rate limit resets
    #
    # @api public
    # @return [Time, nil] the reset time, or nil if the response does not say when the limit resets
    # @example Get the reset time
    #   error.reset_at
    def reset_at
      rate_limit&.reset_at
    end

    # Get the seconds until the rate limit resets
    #
    # @api public
    # @return [Integer, nil] the seconds until reset, or nil if the response does not say when the limit resets
    # @example Get the time until reset
    #   error.reset_in
    def reset_in
      rate_limit&.reset_in
    end

    # @!method retry_after
    #   Alias for reset_in, returns the seconds to wait before retrying
    #
    #   X recommends waiting a minute, doubling the wait for each retry after, when it does not say when the limit
    #   resets.
    #
    #   @api public
    #   @return [Integer, nil] the seconds to wait before retrying, or nil if the response does not say
    #   @example Wait before retrying
    #     sleep(error.retry_after || 60)
    alias_method :retry_after, :reset_in
  end
end
