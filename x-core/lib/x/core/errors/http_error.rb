# frozen_string_literal: true

require "json"
require_relative "error"
require_relative "../problem"
require_relative "../response_headers"

module X
  # Base class for HTTP errors from the X API
  #
  # The message is what the API said went wrong, read from the body of the response. {#body} holds that body as it
  # arrived, {#headers} the headers it came with, and {#problem} the JSON object within it that describes the
  # failure, for code that acts on the reason rather than logging it.
  #
  # @api public
  class HTTPError < Error
    include Core::ResponseHeaders

    # Regular expression to match JSON content types
    JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}
    private_constant :JSON_CONTENT_TYPE_REGEXP
    # The keys of a body that describes the failure itself, rather than naming the errors of the request
    PROBLEM_KEYS = %w[title detail type error].freeze
    private_constant :PROBLEM_KEYS

    # The response itself, as the client received it
    #
    # It is an escape hatch, for what the error does not read: the status is {#status}, the headers are
    # {#headers}, and the body is {#body}. What it holds is what the client sent the request with, which is
    # Net::HTTP today, and the class of it is not part of what 1.x promises.
    #
    # @api public
    # @return [Net::HTTPResponse] the HTTP response
    # @example Read the reason phrase of the status line
    #   error.http_response.message # => "Too Many Requests"
    attr_reader :http_response

    # The problem the API described in the body of the response
    #
    # It is the first error the body names, which is the most specific thing the API said about the request, or
    # else the problem the body describes itself. The whole body is {#body}, so a response that names several
    # errors keeps every one of them there.
    #
    # @api public
    # @return [Problem, nil] the problem, or nil for a response that describes none in JSON
    # @example Tell a parameter the API refused from one it did not understand
    #   error.problem&.parameter # => "ids"
    # @example Act on the reason rather than the status
    #   retry_without(error.problem.value) if error.problem&.not_found?
    attr_reader :problem

    # Initialize a new HTTPError
    #
    # Internal to x-core: ResponseParser raises the errors of the responses it parses, and it takes the Net::HTTP
    # response of a request, so that it can change within 1.x, as that response may.
    #
    # @api private
    # @param http_response [Net::HTTPResponse] the HTTP response
    # @return [HTTPError] a new instance
    # @example Create an HTTP error
    #   error = X::HTTPError.new(http_response: response)
    def initialize(http_response:)
      @http_response = http_response
      parsed = parsed_body
      @problem = Problem.from(problem_from(parsed))
      super(message_from(parsed) || http_response.message)
    end

    # The HTTP status code, as an Integer like X::Response#status
    #
    # @api public
    # @return [Integer] the HTTP status code
    # @example Handle a status the errors do not name
    #   retry if error.status.eql?(408)
    def status = Integer(http_response.code)

    # The body of the response, as it arrived
    #
    # A server can send any body with an error, so it is the JSON the API describes a failure with, or whatever
    # else was sent in its place, such as the page of a proxy.
    #
    # @api public
    # @return [String, nil] the body, or nil for a response without one
    # @example Log what the API sent
    #   logger.error(error.body)
    def body = http_response.body

    private

    # The body of the response, parsed as a JSON object
    #
    # A server can send any body with an error, so a body that is not JSON, or that is not the JSON its content
    # type claims, parses to an empty object rather than raise while the error is built.
    #
    # @api private
    # @return [Hash{String => Object}] the parsed body, empty for a body that is not a JSON object
    def parsed_body
      return {} unless json?

      Hash.try_convert(JSON.parse(body.to_s)) || {}
    rescue JSON::ParserError
      {}
    end

    # The problem a body describes, if it describes one
    #
    # @api private
    # @param body [Hash{String => Object}] the parsed body
    # @return [Hash{String => Object}, nil] the first error the body names, the body itself if it describes the
    #   failure, or nil if it describes none
    def problem_from(body)
      Hash.try_convert(Array(body["errors"]).first) || (body if PROBLEM_KEYS.any? { |key| body.key?(key) })
    end

    # The message a body describes the failure with
    #
    # A body that holds no message leaves the error with the status message of the response.
    #
    # @api private
    # @param body [Hash{String => Object}] the parsed body
    # @return [String, nil] the message, or nil if the body holds none
    def message_from(body)
      message_from_errors(body["errors"]) || message_from_problem(body) || String.try_convert(body["error"])
    end

    # Join the messages of an errors array
    #
    # Each error gives its message, or else its detail or title.
    #
    # @api private
    # @param errors [Object] the errors of the body
    # @return [String, nil] the joined messages, or nil if there are none
    def message_from_errors(errors)
      messages = Array(errors).filter_map do |error|
        Hash.try_convert(error)&.values_at("message", "detail", "title")&.grep(String)&.first
      end
      messages.join(", ") unless messages.empty?
    end

    # The title and detail of a problem, joined
    # @api private
    # @param body [Hash{String => untyped}] the body
    # @return [String, nil] the title and detail, or nil unless the body has both
    def message_from_problem(body)
      title = body["title"]
      detail = body["detail"]
      "#{title}: #{detail}" if title && detail
    end

    # Check whether the response carries JSON
    # @api private
    # @return [Boolean] true if the response is JSON
    def json?
      JSON_CONTENT_TYPE_REGEXP === http_response["content-type"]
    end
  end
end
