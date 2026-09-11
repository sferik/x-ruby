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
    # @return [Array<RateLimit>] the rate limits that are exhausted
    # @example Get all rate limits
    #   error.rate_limits
    def rate_limits
      @rate_limits ||= RateLimit::TYPES.filter_map do |type|
        RateLimit.new(type:, response:) if response["x-#{type}-remaining"].eql?("0")
      end
    end

    # Get the time when the rate limit resets
    #
    # @api public
    # @return [Time] the reset time
    # @example Get the reset time
    #   error.reset_at
    def reset_at
      rate_limit&.reset_at || Time.at(0)
    end

    # Get the seconds until the rate limit resets
    #
    # @api public
    # @return [Integer] the seconds until reset
    # @example Get the time until reset
    #   error.reset_in
    def reset_in
      [(reset_at - Time.now).ceil, 0].max
    end

    # @!method retry_after
    #   Alias for reset_in, returns the seconds to wait before retrying
    #   @api public
    #   @return [Integer] the seconds to wait before retrying
    #   @example Get the retry delay
    #     error.retry_after
    alias_method :retry_after, :reset_in
  end
end
