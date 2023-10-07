require "json"

module X
  # Base error class
  class Error < ::StandardError
    attr_reader :object

    def initialize(msg, response:)
      @object = JSON.parse(response.body) if response&.body && !response.body.empty?
      super(msg)
    end
  end
end
