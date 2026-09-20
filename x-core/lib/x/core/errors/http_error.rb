require "json"
require_relative "error"

module X
  # Base class for HTTP errors from the X API
  # @api public
  class HTTPError < Error
    # Regular expression to match JSON content types
    JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}
    private_constant :JSON_CONTENT_TYPE_REGEXP

    # The HTTP response
    # @api public
    # @return [Net::HTTPResponse] the HTTP response
    # @example Get the response
    #   error.response
    attr_reader :response

    # Initialize a new HTTPError
    #
    # Internal to x-core: ResponseParser raises the errors of the responses it parses, and it takes the Net::HTTP
    # response of a request, so that it can change within 1.x, as that response may.
    #
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [HTTPError] a new instance
    # @example Create an HTTP error
    #   error = X::HTTPError.new(response: response)
    def initialize(response:)
      super(error_message(response))
      @response = response
    end

    # The HTTP status code, as an Integer like X::Response#status
    #
    # @api public
    # @return [Integer] the HTTP status code
    # @example Handle a status the errors do not name
    #   retry if error.status.eql?(408)
    def status = Integer(response.code)

    private

    # Get the error message from the response
    #
    # A server can send any body with an error, so a body that is not the JSON its content type claims, or that
    # holds no message, falls back on the status message rather than raise while the error is built.
    #
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [String] the error message
    def error_message(response)
      (message_from_json_response(response) if json?(response)) || response.message
    end

    # Extract error message from a JSON response
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [String, nil] the error message, or nil if the body holds none
    def message_from_json_response(response)
      body = Hash.try_convert(JSON.parse(response.body.to_s)) || {}
      message_from_errors(body["errors"]) || message_from_problem(body) || String.try_convert(body["error"])
    rescue JSON::ParserError
      nil
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

    # Check if the response contains JSON
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [Boolean] true if the response is JSON
    def json?(response)
      JSON_CONTENT_TYPE_REGEXP === response["content-type"]
    end
  end
end
