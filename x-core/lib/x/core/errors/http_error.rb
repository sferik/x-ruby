require "json"
require_relative "error"

module X
  # Base class for HTTP errors from the X API
  # @api public
  class HTTPError < Error
    # Regular expression to match JSON content types
    JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}

    # The HTTP response
    # @api public
    # @return [Net::HTTPResponse] the HTTP response
    # @example Get the response
    #   error.response
    attr_reader :response

    # The HTTP status code
    # @api public
    # @return [String] the HTTP status code
    # @example Get the status code
    #   error.code
    attr_reader :code

    # Initialize a new HTTPError
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [HTTPError] a new instance
    # @example Create an HTTP error
    #   error = X::HTTPError.new(response: response)
    def initialize(response:)
      super(error_message(response))
      @response = response
      @code = response.code
    end

    # Get the error message from the response
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [String] the error message
    # @example Get the error message
    #   error.error_message(response)
    def error_message(response)
      if json?(response)
        message_from_json_response(response)
      else
        response.message
      end
    end

    # Extract error message from a JSON response
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [String] the error message
    # @example Get error message from JSON
    #   error.message_from_json_response(response)
    def message_from_json_response(response)
      response_object = JSON.parse(response.body)
      if response_object["errors"].instance_of?(Array)
        response_object.fetch("errors").map { |error| error.fetch("message") }.join(", ")
      elsif response_object.key?("title") && response_object.key?("detail")
        "#{response_object.fetch("title")}: #{response_object.fetch("detail")}"
      elsif response_object.key?("error")
        response_object.fetch("error")
      else
        response.message
      end
    end

    # Check if the response contains JSON
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [Boolean] true if the response is JSON
    # @example Check if response is JSON
    #   error.json?(response)
    def json?(response)
      JSON_CONTENT_TYPE_REGEXP === response["content-type"]
    end
  end
end
