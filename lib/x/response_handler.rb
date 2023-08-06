require "json"
require_relative "errors/errors"

module X
  # Process HTTP responses
  class ResponseHandler
    include ClientDefaults
    include Errors

    def initialize(response, array_class, object_class)
      @response = response
      @array_class = array_class
      @object_class = object_class
    end

    def handle
      if successful_json_response?
        return JSON.parse(@response.body, array_class: @array_class, object_class: @object_class)
      end

      error_class = ERROR_CLASSES[@response.code.to_i] || Error
      error_message = "#{@response.code} #{@response.message}"
      raise error_class, error_message if @response.body.nil? || @response.body.empty?

      raise error_class.new(error_message, @response)
    end

    private

    def successful_json_response?
      @response.is_a?(Net::HTTPSuccess) && @response.body && @response["content-type"] == DEFAULT_CONTENT_TYPE
    end
  end
end
