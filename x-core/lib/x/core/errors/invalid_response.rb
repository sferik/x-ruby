require_relative "error"

module X
  # Error raised for a successful response whose body is not JSON, such as the page of a proxy or captive portal
  # @api public
  class InvalidResponse < Error
    # The HTTP response
    # @api public
    # @return [Net::HTTPResponse] the HTTP response
    # @example Read the status of the response
    #   error.response.code
    attr_reader :response

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
    # Internal to x-core: ResponseParser and StreamParser raise it, and it takes the Net::HTTP response of a
    # request, so that it can change within 1.x, as that response may.
    #
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @param body [String, nil] the body that is not JSON
    # @return [InvalidResponse] a new instance
    # @example Create an error
    #   error = X::InvalidResponse.new(response: response, body: response.body)
    # @example Create an error for a line of a stream
    #   error = X::InvalidResponse.new(response: response, body: line)
    def initialize(response:, body: nil)
      super("The body of the #{response.code} response is not JSON (#{response["content-type"] || "no content type"})")
      @response = response
      @body = body
    end
  end
end
