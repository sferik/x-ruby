require_relative "client_error"
require_relative "../client_defaults"

module X
  # Rate limit error
  class TooManyRequestsError < ClientError
    include ClientDefaults

    def initialize(msg, response:, array_class: DEFAULT_ARRAY_CLASS, object_class: DEFAULT_OBJECT_CLASS)
      @response = response
      super
    end

    def limit
      @response.fetch("x-rate-limit-limit", 0).to_i
    end

    def remaining
      @response.fetch("x-rate-limit-remaining", 0).to_i
    end

    def reset_at
      Time.at(@response.fetch("x-rate-limit-reset", 0).to_i).utc
    end

    def reset_in
      [(reset_at - Time.now).ceil, 0].max if reset_at
    end

    alias_method :retry_after, :reset_in
  end
end
