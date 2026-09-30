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
    # The fields of a rate limit, each of which a response reports in a header of its own
    FIELDS = %w[limit remaining reset].freeze
    private_constant :FIELDS
    # The value of a header of a rate limit, which counts requests, or the seconds since the epoch, in base 10
    COUNT = /\A\d+\z/
    private_constant :COUNT

    # The type of rate limit
    # @api public
    # @return [String] the type of rate limit
    # @example Get the rate limit type
    #   rate_limit.type # => "rate-limit"
    attr_reader :type

    # Every rate limit a response reports in full, in the order of TYPES
    #
    # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
    # response may, and is private, so X::Response#rate_limits and X::TooManyRequests#rate_limits, which read the
    # same limits, call it with __send__.
    #
    # @api private
    # @param http_response [Net::HTTPResponse] the HTTP response
    # @return [Array<RateLimit>] the 15-minute limit, and the 24-hour app and user limits, when reported
    # @example Read every limit a response reports
    #   X::RateLimit.__send__(:all_from, http_response)
    def self.all_from(http_response) = TYPES.filter_map { |type| new(type:, http_response:) if reported?(type, http_response) }

    # Check whether a response has the limit, remaining, and reset of a rate limit
    #
    # Each is a count in base 10, and a limit whose header holds anything else, such as a proxy that mangled it, is
    # not reported, rather than read as another number or raise once it is read, which would raise from a refusal
    # in place of the TooManyRequests the refusal is.
    #
    # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
    # response may.
    #
    # @api private
    # @param type [String] the type of rate limit
    # @param http_response [Net::HTTPResponse] the HTTP response
    # @return [Boolean] true if the response has every header of the rate limit, each a count in base 10
    # @example Check for the 15-minute rate limit
    #   X::RateLimit.__send__(:reported?, "rate-limit", response)
    def self.reported?(type, http_response) = FIELDS.all? { |field| http_response["x-#{type}-#{field}"].to_s.match?(COUNT) }
    private_class_method :all_from, :reported?, :new

    # Initialize a new RateLimit
    #
    # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
    # response may, and new is private, so that only all_from builds one, as X::Response#rate_limits and
    # X::TooManyRequests#rate_limits read them.
    #
    # @api private
    # @param type [String] the type of rate limit
    # @param http_response [Net::HTTPResponse] the HTTP response containing rate limit headers
    # @return [RateLimit] a new instance
    # @example Create a rate limit instance
    #   rate_limit = X::RateLimit.__send__(:new, type: "rate-limit", http_response: response)
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
    def limit = field("limit")

    # Get the remaining requests
    #
    # @api public
    # @return [Integer] the number of requests remaining
    # @example Get the remaining requests
    #   rate_limit.remaining
    def remaining = field("remaining")

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
    def reset_at = Time.at(field("reset"))

    # Get the seconds until the rate limit resets
    #
    # @api public
    # @return [Integer] the seconds until the rate limit resets
    # @example Get the reset time in seconds
    #   rate_limit.reset_in
    def reset_in
      [(reset_at - Time.now).ceil, 0].max
    end

    private

    # The response the limit was read from, as the client received it
    #
    # Internal to x-core: the limit reads its headers from it, so that a limit promises nothing of Net::HTTP.
    # {#limit}, {#remaining}, and {#reset_at} are the headers it reports, and X::Response#http_response and
    # X::HTTPError#http_response are the response itself.
    #
    # @api private
    # @return [Net::HTTPResponse] the HTTP response the rate limit headers came with
    attr_reader :http_response

    # Read a field of the rate limit from its header, in base 10
    # @api private
    # @param name [String] the name of the field: limit, remaining, or reset
    # @return [Integer] the value of the field
    def field(name) = Integer(http_response.fetch("x-#{type}-#{name}"), 10)
  end
end
