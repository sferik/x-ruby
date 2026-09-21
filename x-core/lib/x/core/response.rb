# frozen_string_literal: true

require "json"
require "net/http"
require_relative "rate_limit"
require_relative "response_headers"

module X
  # A summary of one API response, or one object of a stream, which a client passes to its on_response hook
  # @api public
  class Response
    include Core::ResponseHeaders

    # The HTTP method of the request
    # @api public
    # @return [Symbol] the HTTP method
    # @example Get the HTTP method
    #   response.http_method # => :get
    attr_reader :http_method

    # The URI of the request
    # @api public
    # @return [URI::Generic] the request URI
    # @example Get the path of the request
    #   response.uri.path # => "/2/users/me"
    attr_reader :uri

    # The response itself, as the client received it
    #
    # It is an escape hatch, for what a summary does not read: the status is {#status}, the headers are
    # {#headers}, and the body is {#body}. What it holds is what the client sent the request with, which is
    # Net::HTTP today, and the class of it is not part of what 1.x promises.
    #
    # @api public
    # @return [Net::HTTPResponse] the HTTP response
    # @example Read the reason phrase of the status line
    #   response.http_response.message # => "OK"
    attr_reader :http_response

    # Summarize a response
    #
    # Internal to x-core: it takes the Net::HTTP response of a request, so that it can change within 1.x, as that
    # response may.
    #
    # @api private
    # @param http_method [Symbol] the HTTP method of the request
    # @param uri [URI::Generic] the URI of the request
    # @param http_response [Net::HTTPResponse] the HTTP response
    # @param body [String, nil] the part of the body summarized, such as one object of a stream, or nil for all of it
    # @return [Response] a new summary
    # @example Summarize a response
    #   X::Response.new(:get, URI("https://api.x.com/2/users/me"), http_response)
    def initialize(http_method, uri, http_response, body: nil)
      @http_method = http_method
      @uri = uri
      @http_response = http_response
      @body = body
    end

    # The body summarized: one streamed object, or else the whole body
    #
    # @api public
    # @return [String, nil] the body
    # @example Log the body
    #   logger.debug(response.body)
    def body = @body || http_response.body

    # The HTTP status code
    #
    # @api public
    # @return [Integer] the status code
    # @example Get the status code
    #   response.status # => 200
    def status = Integer(http_response.code)

    # Check whether the request succeeded
    #
    # @api public
    # @return [Boolean] true for a 2xx status
    # @example Count the failed requests
    #   failures += 1 unless response.success?
    def success? = http_response.is_a?(Net::HTTPSuccess)

    # The rate limits the response reports in its headers
    #
    # @api public
    # @return [Array<RateLimit>] the 15-minute limit, and the 24-hour app and user limits when reported
    # @example Print how many requests remain in each window
    #   response.rate_limits.each { |limit| puts "#{limit.type}: #{limit.remaining}" }
    def rate_limits = RateLimit.all_from(http_response)

    # The 15-minute rate limit of the endpoint, which nearly every response reports
    #
    # @api public
    # @return [RateLimit, nil] the rate limit, or nil if the response reports none
    # @example Slow down near the limit
    #   sleep response.rate_limit.reset_in if response.rate_limit&.remaining&.zero?
    def rate_limit = rate_limits.find { |limit| limit.type.eql?(RateLimit::RATE_LIMIT_TYPE) }

    # The number of resources the body holds, as data and as each kind of include
    #
    # The API bills reads by the resource, so these counts are the units a request consumed. The body is parsed
    # once, however many times a summary is asked what it holds.
    #
    # @api public
    # @return [Hash{String => Integer}] the count of data and of each include, such as users and posts
    # @example Count the users a lookup returned
    #   response.resource_counts # => {"data" => 1, "posts" => 1}
    def resource_counts
      body = parsed_body
      data = body["data"]
      counts = {"data" => Array.try_convert(data)&.size || [data].compact.size}
      body["includes"].to_h.each { |key, resources| counts[key] = Array(resources).size }
      counts
    end

    # The number of resources the body holds, in data and includes together
    #
    # @api public
    # @return [Integer] the resource count
    # @example Total the resources a client has read
    #   total += response.resource_count
    def resource_count = resource_counts.values.sum

    private

    # The body parsed as a JSON object, read once and kept
    #
    # A hook that reads a summary reads a body the client has parsed already, so parsing it again for each count
    # would parse every response of a client twice.
    #
    # @api private
    # @return [Hash{String => Object}] the parsed body
    def parsed_body
      @parsed_body ||= parse_body
    end

    # The body parsed as a JSON object, or an empty one for a body that holds none
    # @api private
    # @return [Hash{String => Object}] the parsed body
    def parse_body
      Hash.try_convert(JSON.parse(body.to_s)) || {}
    rescue JSON::ParserError
      {}
    end
  end
end
