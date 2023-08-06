require "json"

module X
  # Base error class
  class Error < ::StandardError
    include ClientDefaults
    attr_reader :object

    def initialize(msg = nil, response = nil, object_class = DEFAULT_OBJECT_CLASS)
      @object = JSON.parse(response.body, object_class: object_class) if json_response?(response)
      super(msg)
    end

    private

    def json_response?(response)
      response.is_a?(Net::HTTPResponse) && response.body && response["content-type"] == DEFAULT_CONTENT_TYPE
    end
  end
end
