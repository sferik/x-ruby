# frozen_string_literal: true

module X
  # Represents rate limit information from an API response
  # @api public
  class RateLimit
    # Rate limit type identifier
    RATE_LIMIT_TYPE = "rate-limit"
    # App limit type identifier
    APP_LIMIT_TYPE = "app-limit-24hour"
    # User limit type identifier
    USER_LIMIT_TYPE = "user-limit-24hour"
    # All supported rate limit types
    TYPES = [RATE_LIMIT_TYPE, APP_LIMIT_TYPE, USER_LIMIT_TYPE].freeze

    # The type of rate limit
    # @api public
    # @return [String] the type of rate limit
    # @example Get the rate limit type
    #   rate_limit.type # => "rate-limit"
    attr_reader :type

    # The response the limit was read from, as the client received it
    #
    # It is an escape hatch, for what the limit does not read: {#limit}, {#remaining}, and {#reset_at} are the
    # headers it reports, and X::Response#headers and X::HTTPError#headers are all of them. It is the Net::HTTP
    # response the client sent the request with.
    #
    # @api public
    # @return [Net::HTTPResponse] the HTTP response the rate limit headers came with
    # @example Read the reason phrase of the status line
    #   rate_limit.http_response.message # => "Too Many Requests"
    attr_reader :http_response

    # Every rate limit a response reports in full, in the order of TYPES
    #
    # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
    # response may. X::Response#rate_limits and X::TooManyRequests#rate_limits read the same limits.
    #
    # @api private
    # @param http_response [Net::HTTPResponse] the HTTP response
    # @return [Array<RateLimit>] the 15-minute limit, and the 24-hour app and user limits, when reported
    # @example Read every limit a response reports
    #   X::RateLimit.all_from(http_response)
    def self.all_from(http_response) = TYPES.filter_map { |type| new(type:, http_response:) if reported?(type, http_response) }

    # Check whether a response has the limit, remaining, and reset of a rate limit
    #
    # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
    # response may.
    #
    # @api private
    # @param type [String] the type of rate limit
    # @param http_response [Net::HTTPResponse] the HTTP response
    # @return [Boolean] true if the response has every header of the rate limit
    # @example Check for the 15-minute rate limit
    #   X::RateLimit.reported?("rate-limit", response)
    def self.reported?(type, http_response) = %w[limit remaining reset].all? { |field| http_response.key?("x-#{type}-#{field}") }

    # Initialize a new RateLimit
    #
    # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
    # response may.
    #
    # @api private
    # @param type [String] the type of rate limit
    # @param http_response [Net::HTTPResponse] the HTTP response containing rate limit headers
    # @return [RateLimit] a new instance
    # @example Create a rate limit instance
    #   rate_limit = X::RateLimit.new(type: "rate-limit", http_response: response)
    def initialize(type:, http_response:)
      @type = type
      @http_response = http_response
    end

    # Get the rate limit maximum
    #
    # @api public
    # @return [Integer] the maximum number of requests allowed
    # @example Get the rate limit
    #   rate_limit.limit
    def limit
      Integer(http_response.fetch("x-#{type}-limit"))
    end

    # Get the remaining requests
    #
    # @api public
    # @return [Integer] the number of requests remaining
    # @example Get the remaining requests
    #   rate_limit.remaining
    def remaining
      Integer(http_response.fetch("x-#{type}-remaining"))
    end

    # Check whether the limit has no requests left
    #
    # @api public
    # @return [Boolean] true if no requests remain in the window
    # @example Wait for a limit that is used up
    #   sleep rate_limit.reset_in if rate_limit.exhausted?
    def exhausted? = remaining.zero?

    # Get the time when the rate limit resets
    #
    # @api public
    # @return [Time] the time when the rate limit resets
    # @example Get the reset time
    #   rate_limit.reset_at
    def reset_at
      Time.at(Integer(http_response.fetch("x-#{type}-reset")))
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
  end
end
