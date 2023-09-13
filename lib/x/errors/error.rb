require "json"
require "net/http"

module X
  # Base error class
  class Error < ::StandardError
    JSON_CONTENT_TYPE_REGEXP = %r{application/(problem\+|)json}

    attr_reader :object

    def initialize(msg, response:)
      @object = JSON.parse(response.body || "{}") if JSON_CONTENT_TYPE_REGEXP.match?(response["content-type"])
      super(msg)
    end
  end
end
