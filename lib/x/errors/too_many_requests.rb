require_relative "client_error"
require_relative "../rate_limit"

module X
  class TooManyRequests < ClientError
    def rate_limit
      rate_limits.max_by(&:reset_at)
    end

    def rate_limits
      @rate_limits ||= limit_types.map { |type| RateLimit.new(type: type, response: response) }
        .select { |limit| limit.remaining.zero? }
    end

    def reset_at
      rate_limit&.reset_at || Time.at(0)
    end

    def reset_in
      [(reset_at - Time.now).ceil, 0].max
    end

    alias_method :retry_after, :reset_in

    private

    def limit_types
      @limit_types ||= response.to_hash.keys.filter_map { |k| k.match(/x-(.+-limit.*)-remaining/)&.captures&.first }
    end
  end
end
