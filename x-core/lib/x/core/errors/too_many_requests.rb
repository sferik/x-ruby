require_relative "client_error"
require_relative "../rate_limit"

module X
  # Error raised when rate limit is exceeded (HTTP 429)
  # @api public
  class TooManyRequests < ClientError
    # The rate limits the response reports in its headers, as X::Response reports them
    #
    # @api public
    # @return [Array<RateLimit>] the 15-minute limit, and the 24-hour app and user limits when reported
    # @example Print how many requests remain in each window
    #   error.rate_limits.each { |limit| puts "#{limit.type}: #{limit.remaining}" }
    def rate_limits
      @rate_limits ||= RateLimit.all_from(response)
    end

    # The 15-minute rate limit of the endpoint, which nearly every response reports
    #
    # @api public
    # @return [RateLimit, nil] the rate limit, or nil if the response reports none
    # @example Read how many of the 15-minute requests are left
    #   error.rate_limit&.remaining # => 3
    def rate_limit = rate_limits.find { |limit| limit.type.eql?(RateLimit::RATE_LIMIT_TYPE) }

    # The rate limits with no requests left, one of which refused the request
    #
    # @api public
    # @return [Array<RateLimit>] the reported limits that are exhausted
    # @example Name the windows that are used up
    #   error.exhausted_rate_limits.map(&:type) # => ["app-limit-24hour"]
    def exhausted_rate_limits = rate_limits.select(&:exhausted?)

    # The exhausted rate limit that resets last, which a request waits for
    #
    # @api public
    # @return [RateLimit, nil] the limit, or nil if the response reports none as exhausted
    # @example Name the window that refused the request
    #   error.limiting_rate_limit&.type # => "app-limit-24hour"
    def limiting_rate_limit = exhausted_rate_limits.max_by(&:reset_at)

    # Get the time when the rate limit resets
    #
    # @api public
    # @return [Time, nil] the reset time, or nil if the response does not say when the limit resets
    # @example Get the reset time
    #   error.reset_at
    def reset_at
      limiting_rate_limit&.reset_at
    end

    # Get the seconds until the rate limit resets
    #
    # @api public
    # @return [Integer, nil] the seconds until reset, or nil if the response does not say when the limit resets
    # @example Get the time until reset
    #   error.reset_in
    def reset_in
      limiting_rate_limit&.reset_in
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
