require_relative "client_error"

module X
  # Rate limit error
  class TooManyRequests < ClientError
    def initialize(msg, response = {})
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
      [(reset_at - Time.now).ceil, 0].max
    end

    alias_method :retry_after, :reset_in
  end
end
