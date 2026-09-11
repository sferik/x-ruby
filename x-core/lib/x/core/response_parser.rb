require "json"
require "net/http"
require_relative "errors/bad_gateway"
require_relative "errors/bad_request"
require_relative "errors/connection_exception"
require_relative "errors/http_error"
require_relative "errors/forbidden"
require_relative "errors/gateway_timeout"
require_relative "errors/gone"
require_relative "errors/internal_server_error"
require_relative "errors/not_acceptable"
require_relative "errors/not_found"
require_relative "errors/payload_too_large"
require_relative "errors/service_unavailable"
require_relative "errors/too_many_requests"
require_relative "errors/unauthorized"
require_relative "errors/unprocessable_entity"

module X
  # Parses HTTP responses from the X API
  # @api public
  class ResponseParser
    # Mapping of HTTP status codes to error classes
    ERROR_MAP = {
      400 => BadRequest,
      401 => Unauthorized,
      403 => Forbidden,
      404 => NotFound,
      406 => NotAcceptable,
      409 => ConnectionException,
      410 => Gone,
      413 => PayloadTooLarge,
      422 => UnprocessableEntity,
      429 => TooManyRequests,
      500 => InternalServerError,
      502 => BadGateway,
      503 => ServiceUnavailable,
      504 => GatewayTimeout
    }.freeze

    # Parse an HTTP response
    #
    # @api public
    # @param response [Net::HTTPResponse] the HTTP response to parse
    # @param array_class [Class, nil] the class for parsing JSON arrays
    # @param object_class [Class, nil] the class for parsing JSON objects
    # @return [Hash, Array, nil] the parsed response body
    # @raise [HTTPError] if the response is not successful
    # @example Parse a response
    #   parser.parse(response: response)
    def parse(response:, array_class: nil, object_class: nil)
      raise error(response) unless response.is_a?(Net::HTTPSuccess)

      return if response.instance_of?(Net::HTTPNoContent)

      begin
        JSON.parse(response.body, array_class:, object_class:)
      rescue JSON::ParserError
        nil
      end
    end

    private

    # Create an error from a response
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [HTTPError] the error
    def error(response)
      error_class(response).new(response:)
    end

    # Get the error class for a response
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [Class] the error class
    def error_class(response)
      ERROR_MAP[Integer(response.code)] || HTTPError
    end
  end
end
