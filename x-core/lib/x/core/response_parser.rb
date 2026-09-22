# frozen_string_literal: true

require "json"
require "net/http"
require_relative "errors/bad_gateway"
require_relative "errors/bad_request"
require_relative "errors/conflict"
require_relative "errors/http_error"
require_relative "errors/invalid_response"
require_relative "errors/forbidden"
require_relative "errors/gateway_timeout"
require_relative "errors/gone"
require_relative "errors/internal_server_error"
require_relative "errors/method_not_allowed"
require_relative "errors/not_acceptable"
require_relative "errors/not_found"
require_relative "errors/payload_too_large"
require_relative "errors/request_timeout"
require_relative "errors/service_unavailable"
require_relative "errors/too_many_requests"
require_relative "errors/unauthorized"
require_relative "errors/unavailable_for_legal_reasons"
require_relative "errors/unprocessable_entity"
require_relative "errors/unsupported_media_type"

module X
  module Core
    # Parses HTTP responses from the X API
    #
    # Internal to x-core: Client and StreamingClient parse responses with it.
    #
    # @api private
    class ResponseParser
      # Mapping of HTTP status codes to error classes
      ERROR_MAP = {
        400 => BadRequest,
        401 => Unauthorized,
        403 => Forbidden,
        404 => NotFound,
        405 => MethodNotAllowed,
        406 => NotAcceptable,
        408 => RequestTimeout,
        409 => Conflict,
        410 => Gone,
        413 => PayloadTooLarge,
        415 => UnsupportedMediaType,
        422 => UnprocessableEntity,
        429 => TooManyRequests,
        451 => UnavailableForLegalReasons,
        500 => InternalServerError,
        502 => BadGateway,
        503 => ServiceUnavailable,
        504 => GatewayTimeout
      }.freeze
      # Error classes for the statuses ERROR_MAP does not name, keyed by the class of status: 4xx or 5xx
      STATUS_CLASS_ERRORS = {4 => ClientError, 5 => ServerError}.freeze

      # Parse an HTTP response
      #
      # A successful response without a body, such as 204 No Content, parses to nil. One whose body is not JSON
      # raises, rather than parse to nil as though the response had no body.
      #
      # @api private
      # @param response [Net::HTTPResponse] the HTTP response to parse
      # @param array_class [Class, nil] the class for parsing JSON arrays
      # @param object_class [Class, nil] the class for parsing JSON objects, or a class that builds objects from
      #   the whole body (see {#decode})
      # @param client [Client, nil] the client that made the request
      # @param request [Net::HTTPRequest, nil] the request the response answers, which its error names
      # @return [Object, nil] the parsed response body
      # @raise [HTTPError] if the response is not successful
      # @raise [InvalidResponse] if the body of a successful response is not JSON
      # @example Parse a response
      #   parser.parse(response: response, request: request)
      def parse(response:, array_class: nil, object_class: nil, client: nil, request: nil)
        raise error(response, request) unless response.is_a?(Net::HTTPSuccess)

        body = response.body.to_s
        return unless body.match?(/\S/)

        begin
          decode(body, array_class:, object_class:, client:)
        rescue JSON::ParserError
          raise InvalidResponse.new(http_response: response, body:, request:)
        end
      end

      # Decode a JSON document into the classes a request asked for
      #
      # JSON gives every object in a document the same object_class, at every depth. A class that
      # models a whole response instead responds to from_response, which receives the document
      # parsed into Hashes and Arrays along with the client, and whatever it returns is the result.
      #
      # @api private
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
      # @param request [Net::HTTPRequest, nil] the request the response answers, which the error names
      # @return [HTTPError] the error
      def error(response, request)
        error_class(response).new(http_response: response, request:)
      end

      # Get the error class for a response, falling back on its class of status
      # @api private
      # @param response [Net::HTTPResponse] the HTTP response
      # @return [Class] the error class
      def error_class(response)
        status = Integer(response.code)
        ERROR_MAP.fetch(status) { STATUS_CLASS_ERRORS.fetch(status / 100, HTTPError) }
      end
    end
  end
end
