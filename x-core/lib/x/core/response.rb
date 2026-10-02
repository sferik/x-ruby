# frozen_string_literal: true

require "json"
require "net/http"
require_relative "built_response"
require_relative "rate_limit"
require_relative "response_headers"

module X
  module Core
    # A summary of one API response, or one object of a stream, which a client passes to its on_response hook
    # @api public
    class ::X::Response
      include ResponseHeaders

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
      # {#headers}, and the body is {#body}. It is the Net::HTTP response the client sent the request with, or the one
      # built of the status, headers, and body the summary was given.
      #
      # @api public
      # @return [Net::HTTPResponse] the HTTP response
      # @example Read the reason phrase of the status line
      #   response.http_response.message # => "OK"
      attr_reader :http_response

      # Summarize a response
      #
      # Public, so that an on_response hook can be tested with a summary built from the status, headers, and body of
      # a response, or from a Net::HTTP response, as the client builds one for each response it reads.
      #
      # @api public
      # @param http_method [Symbol, String] the HTTP method of the request, in any case, which is read as a lowercase
      #   Symbol, as an error reads it
      # @param uri [URI::Generic] the URI of the request
      # @param http_response [Net::HTTPResponse, nil] the HTTP response, or nil for one built of the status, headers,
      #   and body
      # @param status [Integer, nil] the status of the response, from 100 to 599, when it is not given
      # @param headers [Hash{String => String}, nil] the headers of the response, when it is not given
      # @param body [String, nil] the part of the body summarized, such as one object of a stream, or nil for all of
      #   it, which is the body of a response built of the status
      # @return [Response] a new summary
      # @raise [ArgumentError] if the HTTP response is given beside a status or headers, or neither it nor a status is
      #   given, or the status is not from 100 to 599, or the headers are not a Hash of names to values
      # @example Summarize a response
      #   X::Response.new(http_method: :get, uri: URI("https://api.x.com/2/users/me"), status: 200,
      #     headers: {"x-rate-limit-remaining" => "74"}, body: %({"data":{"id":"1"}}))
      # @example Summarize a Net::HTTP response
      #   X::Response.new(http_response:, http_method: :get, uri: URI("https://api.x.com/2/users/me"))
      def initialize(http_method:, uri:, http_response: nil, status: nil, headers: nil, body: nil)
        @http_method = http_method.downcase.to_sym
        @uri = uri
        @http_response = BuiltResponse.of(http_response, status:, headers:, body: (body if http_response.nil?))
        @body = body
      end

      # The body summarized: one streamed object, or else the whole body
      #
      # It is tagged UTF-8, the encoding of the JSON the API sends. A body that is not valid UTF-8 keeps its bytes, so
      # valid_encoding? tells it apart, and scrub replaces what is not UTF-8.
      #
      # @api public
      # @return [String, nil] the body, tagged UTF-8
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
      def rate_limits = RateLimit.__send__(:all_from, http_response)

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
end
