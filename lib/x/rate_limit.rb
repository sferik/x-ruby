module X
  # Represents rate limit information from an API response
  # @api public
  class RateLimit
    # Rate limit type identifier
    RATE_LIMIT_TYPE = "rate-limit".freeze
    # App limit type identifier
    APP_LIMIT_TYPE = "app-limit-24hour".freeze
    # User limit type identifier
    USER_LIMIT_TYPE = "user-limit-24hour".freeze
    # All supported rate limit types
    TYPES = [RATE_LIMIT_TYPE, APP_LIMIT_TYPE, USER_LIMIT_TYPE].freeze

    # The type of rate limit
    # @api public
    # @return [String] the type of rate limit
    # @example Get or set the rate limit type
    #   rate_limit.type = "rate-limit"
    attr_accessor :type

    # The HTTP response containing rate limit headers
    # @api public
    # @return [Net::HTTPResponse] the HTTP response containing rate limit headers
    # @example Get or set the response
    #   rate_limit.response = http_response
    attr_accessor :response

    # Initialize a new RateLimit
    #
    # @api public
    # @param type [String] the type of rate limit
    # @param response [Net::HTTPResponse] the HTTP response containing rate limit headers
    # @return [RateLimit] a new instance
    # @example Create a rate limit instance
    #   rate_limit = X::RateLimit.new(type: "rate-limit", response: response)
    def initialize(type:, response:)
      @type = type
      @response = response
    end

    # Get the rate limit maximum
    #
    # @api public
    # @return [Integer] the maximum number of requests allowed
    # @example Get the rate limit
    #   rate_limit.limit
    def limit
      Integer(response.fetch("x-#{type}-limit"))
    end

    # Get the remaining requests
    #
    # @api public
    # @return [Integer] the number of requests remaining
    # @example Get the remaining requests
    #   rate_limit.remaining
    def remaining
      Integer(response.fetch("x-#{type}-remaining"))
    end

    # Get the time when the rate limit resets
    #
    # @api public
    # @return [Time] the time when the rate limit resets
    # @example Get the reset time
    #   rate_limit.reset_at
    def reset_at
      Time.at(Integer(response.fetch("x-#{type}-reset")))
    end

    # Get the seconds until the rate limit resets
    #
    # @api public
    # @return [Integer] the seconds until the rate limit resets
    # @example Get the reset time in seconds
    #   rate_limit.reset_in
    def reset_in
      [(reset_at - Time.now).ceil, 0].max
    end

    # @!method retry_after
    #   Alias for reset_in, returns the seconds until the rate limit resets
    #   @api public
    #   @return [Integer] the seconds until the rate limit resets
    #   @example Get the retry after time
    #     rate_limit.retry_after
    alias_method :retry_after, :reset_in
  end
end
