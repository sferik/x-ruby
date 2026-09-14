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
    # @param object_class [Class, nil] the class for parsing JSON objects, or a class that builds objects from
    #   the whole body (see {#decode})
    # @param client [Client, nil] the client that made the request
    # @return [Object, nil] the parsed response body
    # @raise [HTTPError] if the response is not successful
    # @example Parse a response
    #   parser.parse(response: response)
    def parse(response:, array_class: nil, object_class: nil, client: nil)
      raise error(response) unless response.is_a?(Net::HTTPSuccess)

      return if response.instance_of?(Net::HTTPNoContent)

      begin
        decode(response.body, array_class:, object_class:, client:)
      rescue JSON::ParserError
        nil
      end
    end

    # Decode a JSON document into the classes a request asked for
    #
    # JSON gives every object in a document the same object_class, at every depth. A class that
    # models a whole response instead responds to from_response, which receives the document
    # parsed into Hashes and Arrays along with the client, and whatever it returns is the result.
    #
    # @api public
    # @param json [String] the JSON document
    # @param array_class [Class, nil] the class for parsing JSON arrays
    # @param object_class [Class, #from_response, nil] the class for parsing JSON objects, or one that
    #   builds objects from the whole document
    # @param client [Client, nil] the client that made the request, passed to from_response
    # @return [Object] the decoded document
    # @raise [JSON::ParserError] if the document is not valid JSON
    # @example Decode a document into the default classes
    #   parser.decode('{"data": {"id": "1"}}') # => {"data" => {"id" => "1"}}
    def decode(json, array_class: nil, object_class: nil, client: nil)
      return JSON.parse(json, array_class:, object_class:) unless object_class.respond_to?(:from_response)

      object_class.from_response(JSON.parse(json), client:)
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
