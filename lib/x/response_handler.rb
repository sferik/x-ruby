require "json"
require "net/http"
require_relative "errors/bad_gateway"
require_relative "errors/bad_request"
require_relative "errors/connection_exception"
require_relative "errors/error"
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
  # Process HTTP responses
  class ResponseHandler
    DEFAULT_ARRAY_CLASS = Array
    DEFAULT_OBJECT_CLASS = Hash
    ERROR_CLASSES = {
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
    JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}

    attr_accessor :array_class, :object_class

    def initialize(array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)
      @array_class = array_class
      @object_class = object_class
    end

    def handle(response)
      raise error(response) unless success?(response)

      JSON.parse(response.body, array_class: array_class, object_class: object_class) if json?(response)
    end

    private

    def success?(response)
      response.is_a?(Net::HTTPSuccess)
    end

    def error(response)
      error_class(response).new(error_message(response), response)
    end

    def error_class(response)
      ERROR_CLASSES[response.code.to_i] || Error
    end

    def error_message(response)
      if json?(response)
        message_from_json_response(response)
      else
        response.message
      end
    end

    def message_from_json_response(response)
      response_object = JSON.parse(response.body)
      if response_object["title"] || response_object["detail"]
        "#{response_object["title"]}: #{response_object["detail"]}"
      elsif response_object["error"]
        response_object["error"]
      elsif response_object["errors"].is_a?(Array)
        response_object["errors"].map { |error| error["message"] }.join(", ")
      else
        response.message
      end
    end

    def json?(response)
      response.body && JSON_CONTENT_TYPE_REGEXP.match?(response["content-type"])
    end
  end
end
