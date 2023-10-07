require "json"
require "net/http"
require_relative "errors/authentication_error"
require_relative "errors/bad_request_error"
require_relative "errors/forbidden_error"
require_relative "errors/not_found_error"
require_relative "errors/payload_too_large_error"
require_relative "errors/internal_server_error"
require_relative "errors/service_unavailable_error"
require_relative "errors/too_many_requests_error"

module X
  # Process HTTP responses
  class ResponseHandler
    DEFAULT_ARRAY_CLASS = Array
    DEFAULT_OBJECT_CLASS = Hash
    ERROR_CLASSES = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => ForbiddenError,
      404 => NotFoundError,
      413 => PayloadTooLargeError,
      429 => TooManyRequestsError,
      500 => InternalServerError,
      503 => ServiceUnavailableError
    }.freeze
    JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}

    attr_accessor :array_class, :object_class

    def initialize(array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)
      @array_class = array_class
      @object_class = object_class
    end

    def handle(response)
      if success?(response)
        JSON.parse(response.body, array_class: array_class, object_class: object_class) if json?(response)
      else
        error_class = ERROR_CLASSES[response.code.to_i] || Error
        error_message = "#{response.code} #{response.message}"
        raise error_class.new(error_message, response: response)
      end
    end

    def configuration
      {
        array_class: array_class,
        object_class: object_class
      }
    end

    private

    def success?(response)
      response.is_a?(Net::HTTPSuccess)
    end

    def json?(response)
      response.body && JSON_CONTENT_TYPE_REGEXP.match?(response["content-type"])
    end
  end
end
