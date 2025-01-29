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
  class ResponseParser
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

    def parse(response:, array_class: nil, object_class: nil)
      raise error(response) unless response.is_a?(Net::HTTPSuccess)

      return if !json?(response) || response.instance_of?(Net::HTTPNoContent)

      JSON.parse(response.body, array_class:, object_class:)
    end

    private

    def json?(response)
      JSON.parse(response.body)
      true
    rescue JSON::ParserError, TypeError
      false
    end

    def error(response)
      error_class(response).new(response:)
    end

    def error_class(response)
      ERROR_MAP[Integer(response.code)] || HTTPError
    end
  end
end
