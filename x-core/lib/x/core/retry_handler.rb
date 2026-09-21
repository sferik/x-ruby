# frozen_string_literal: true

require_relative "errors/network_error"
require_relative "errors/server_error"

module X
  module Core
    # Sends a request again after the API failed to answer it, or after its answer never arrived
    #
    # Internal to x-core: Client retries with it, and takes max_retries.
    #
    # @api private
    class RetryHandler
      # Default maximum number of retries, which sends an idempotent request twice more before it raises
      DEFAULT_MAX_RETRIES = 2
      # Seconds to wait before the first retry, doubled for each retry after
      INITIAL_WAIT = 1
      # The failures a retry may follow, neither of which the request itself is the reason for
      RETRIABLE_ERRORS = [NetworkError, ServerError].freeze

      # The maximum number of times to send an idempotent request again after a failure
      # @api private
      # @return [Integer] the maximum number of retries
      # @example Read the maximum retries
      #   handler.max_retries # => 2
      attr_reader :max_retries

      # Initialize a new retry handler
      #
      # @api private
      # @param max_retries [Integer] the maximum number of times to send an idempotent request again
      # @return [RetryHandler] a new instance
      # @example Create a handler that sends a failed request twice more
      #   handler = X::Core::RetryHandler.new(max_retries: 2)
      def initialize(max_retries: DEFAULT_MAX_RETRIES)
        @max_retries = max_retries
      end

      # Run a request, running it again after a failure of the API or of the network
      #
      # A request is sent again while retries remain, after waiting up to a second before the first retry and up to
      # twice as long before each retry after. Only an idempotent request is retried: the API may have acted on a
      # POST whose answer never arrived, so sending that again could post twice. The block must build its request
      # anew each time, so that each attempt is signed afresh.
      #
      # @api private
      # @param idempotent [Boolean] whether sending the request again has the same effect as sending it once
      # @yield runs the request
      # @return [Object] what the block returns
      # @raise [NetworkError] if the request fails once more than the retries allow
      # @raise [ServerError] if the API fails to answer once more than the retries allow
      # @example Retry a lookup
      #   handler.handle(idempotent: true) { client.get("users/me") }
      def handle(idempotent:)
        retries = 0
        begin
          yield
        rescue *RETRIABLE_ERRORS
          retries += 1
          raise unless idempotent && retries <= max_retries

          sleep(wait_before_retry(retries))
          retry
        end
      end

      private

      # The seconds to wait before a retry
      #
      # The wait doubles with each retry, and a random share of up to half of it is taken off. The share is what
      # keeps the requests apart: a failure of the API fails every request in flight at once, and requests that
      # waited the same time would be sent again together, to fail together once more.
      #
      # @api private
      # @param retries [Integer] the number of the retry, counting from one
      # @return [Float] the seconds to wait
      def wait_before_retry(retries)
        wait = INITIAL_WAIT << (retries - 1)
        wait - (rand * wait / 2)
      end
    end
  end
end
