module X
  class RateLimit
    attr_accessor :type, :response

    def initialize(type:, response:)
      @type = type
      @response = response
    end

    def limit
      Integer(response.fetch("x-#{type}-limit"))
    end

    def remaining
      Integer(response.fetch("x-#{type}-remaining"))
    end

    def reset_at
      Time.at(Integer(response.fetch("x-#{type}-reset")))
    end

    def reset_in
      [(reset_at - Time.now).ceil, 0].max
    end

    alias_method :retry_after, :reset_in
  end
end
