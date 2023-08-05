module X
  # HTTP client that handles authentication and requests
  class Client
    # Base error class
    class Error < ::StandardError
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

    class NetworkError < Error; end

    class ClientError < Error; end

    class AuthenticationError < ClientError; end

    class BadRequestError < ClientError; end

    class ForbiddenError < ClientError; end

    class NotFoundError < ClientError; end

    # Rate limit error
    class TooManyRequestsError < ClientError
      def initialize(msg, response = nil, object_class = DEFAULT_OBJECT_CLASS)
        @response = response
        super
      end

      def limit
        @response&.fetch("x-rate-limit-limit", 0).to_i
      end

      def remaining
        @response&.fetch("x-rate-limit-remaining", 0).to_i
      end

      def reset_at
        Time.at(@response&.fetch("x-rate-limit-reset", 0).to_i).utc if @response
      end

      def reset_in
        [(reset_at - Time.now).ceil, 0].max if reset_at
      end

      alias_method :retry_after, :reset_in
    end

    class ServerError < Error; end

    class ServiceUnavailableError < ServerError; end

    ERROR_CLASSES = {
      400 => BadRequestError,
      401 => AuthenticationError,
      403 => ForbiddenError,
      404 => NotFoundError,
      429 => TooManyRequestsError,
      500 => ServerError,
      503 => ServiceUnavailableError
    }.freeze

    NETWORK_ERRORS = [
      Errno::ECONNREFUSED,
      Net::OpenTimeout,
      Net::ReadTimeout
    ].freeze
  end
end
