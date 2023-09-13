require "json"
require "net/http"
require_relative "errors/errors"

module X
  # Process HTTP responses
  class ResponseHandler
    DEFAULT_ARRAY_CLASS = Array
    DEFAULT_OBJECT_CLASS = Hash
    JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}
    include Errors

    attr_accessor :array_class, :object_class

    def initialize(array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)
      @array_class = array_class
      @object_class = object_class
    end

    def handle(response)
      if successful_json_response?(response)
        return JSON.parse(response.body, array_class: array_class, object_class: object_class)
      end

      error_class = ERROR_CLASSES[response.code.to_i] || Error
      error_message = "#{response.code} #{response.message}"
      raise error_class.new(error_message, response: response)
    end

    private

    def successful_json_response?(response)
      response.is_a?(Net::HTTPSuccess) && response.body && JSON_CONTENT_TYPE_REGEXP.match?(response["content-type"])
    end
  end
end
