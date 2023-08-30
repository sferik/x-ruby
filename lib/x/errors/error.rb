require "json"
require "net/http"
require_relative "../client_defaults"

module X
  # Base error class
  class Error < ::StandardError
    include ClientDefaults
    attr_reader :object

    def initialize(msg, response:, array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)
      if json_response?(response)
        @object = JSON.parse(response.body, array_class: array_class, object_class: object_class)
      end
      super(msg)
    end

    private

    def json_response?(response)
      response.is_a?(Net::HTTPResponse) && response.body && response["content-type"] == DEFAULT_CONTENT_TYPE
    end
  end
end
