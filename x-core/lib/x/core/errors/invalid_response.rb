# frozen_string_literal: true

require_relative "error"
require_relative "../request_context"

module X
  # Error raised for a successful response whose body is not JSON, such as the page of a proxy or captive portal
  # @api public
  class InvalidResponse < Error
    include Core::RequestContext

    # The HTTP response
    # @api public
    # @return [Net::HTTPResponse] the HTTP response
    # @example Read the status of the response
    #   error.http_response.code
    attr_reader :http_response

    # The body that is not JSON: the whole body of a response, or the line of a stream
    #
    # The body of a stream can be read only as it arrives, so an error raised for a line of a stream holds that line.
    #
    # @api public
    # @return [String, nil] the body, or the line of a stream, or nil for an error built without one
    # @example Read the body that could not be parsed
    #   error.body
    attr_reader :body

    # Initialize a new InvalidResponse
    #
    # Internal to x-core: ResponseParser and StreamParser raise it, and it takes the Net::HTTP request and response
    # of a request, so that either can change within 1.x, as they may.
    #
    # @api private
    # @param http_response [Net::HTTPResponse] the HTTP response
    # @param body [String, nil] the body that is not JSON
    # @param request [Net::HTTPRequest, nil] the request the response answers, which the error names
    # @return [InvalidResponse] a new instance
    # @example Create an error
    #   error = X::InvalidResponse.new(http_response: response, body: response.body)
    # @example Create an error for a line of a stream
    #   error = X::InvalidResponse.new(http_response: response, body: line, request: request)
    def initialize(http_response:, body: nil, request: nil)
      name_request(request)
      super(message_naming_request("The body of the #{http_response.code} response is not JSON (#{http_response["content-type"] || "no content type"})"))
      @http_response = http_response
      @body = body
    end
  end
end
