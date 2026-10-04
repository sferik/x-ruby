# frozen_string_literal: true

require "net/http"
require "socket"
require_relative "errors/callback_error"
require_relative "errors/http_error"
require_relative "errors/network_error"
require_relative "errors/request_timeout"
require_relative "errors/server_error"
require_relative "setting_validator"

module X
  module Core
    # Sends a request again after the API failed to answer it, or after its answer never arrived
    #
    # Internal to x-core: Client retries with it, and takes max_retries, and Client#with_retries sends a request
    # again with it that a client sends no more than once, as it does any POST.
    #
    # @api private
    class RetryHandler
      # Default maximum number of retries, which sends an idempotent request twice more before it raises
      DEFAULT_MAX_RETRIES = 2
      # Seconds to wait before the first retry, doubled for each retry after, up to MAX_RETRY_AFTER
      INITIAL_WAIT = 1
      # The longest wait a response may ask for that a request waits out before it is sent again, and the longest the
      # backoff grows to; a response that asks to be left alone for longer raises at once, rather than hold a caller for
      # minutes on end
      MAX_RETRY_AFTER = 60
      # The failures a retry may follow, none of which the request itself is the reason for: a 408 says the API gave
      # up waiting for the request, not that it refused it
      RETRIABLE_ERRORS = [NetworkError, ServerError, RequestTimeout].freeze
      # The errors of a socket, the cause of a NetworkError, that fail a request before any of it is written: a host
      # that cannot be resolved or reached, a connection refused, and a connection or TLS handshake that timed out
      UNSENT_ERRORS = [Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, Net::OpenTimeout, SocketError].freeze

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
      # @raise [ArgumentError] if the maximum number of retries is not an Integer of at least 0
      # @example Create a handler that sends a failed request twice more
      #   handler = X::Core::RetryHandler.new(max_retries: 2)
      def initialize(max_retries: DEFAULT_MAX_RETRIES)
        @max_retries = SettingValidator.count!(:max_retries, max_retries)
      end

      # Run a request, running it again after a failure of the API or of the network
      #
      # A request is sent again while retries remain, after waiting up to a second before the first retry and up to
      # twice as long before each retry after, but never more than MAX_RETRY_AFTER, or for as long as the response asks
      # when it carries a Retry-After header, whichever is longer. A response that asks to be left alone for longer than MAX_RETRY_AFTER raises
      # at once, since waiting it out would hold the caller for minutes. Only an idempotent request is retried: the
      # API may have acted on a POST whose answer never arrived, so sending that again could post twice. The block
      # must build its request anew each time, so that each attempt is signed afresh.
      #
      # A TooManyRequests is not retried here: a request sent again before its rate limit resets is refused again, so
      # RateLimitHandler waits for the reset instead, for as long as max_rate_limit_wait allows, well past
      # MAX_RETRY_AFTER.
      #
      # A NetworkError is retried only when the request never left: a request that timed out reading its response,
      # or whose connection dropped once it was written, may have been answered, and the API bills a read it answered
      # whether or not the answer arrived, so sending it again could bill it again. resend_unanswered retries those
      # too, for a request the API bills nothing for, such as the chunk of an upload.
      #
      # An error a callback of the request raised, such as on_response, is not the API's failure, and is raised as it
      # is, so that a request Client#with_retries wraps is not sent again for it, though the API answered it.
      #
      # @api private
      # @param idempotent [Boolean] whether sending the request again has the same effect as sending it once
      # @param resend_unanswered [Boolean] whether to send the request again after a NetworkError that may have come
      #   after the API received it
      # @yield runs the request
      # @return [Object] what the block returns
      # @raise [NetworkError] if the request fails once more than the retries allow
      # @raise [ServerError, RequestTimeout] if the API fails to answer once more than the retries allow, or asks for a
      #   wait longer than MAX_RETRY_AFTER
      # @example Retry a lookup
      #   handler.handle(idempotent: true) { client.get("users/me") }
      def handle(idempotent:, resend_unanswered: false)
        retries = 0
        begin
          yield
        rescue *RETRIABLE_ERRORS => e
          retries += 1
          requested = retry_after(e)
          raise unless idempotent && retries <= max_retries && requested.to_i <= MAX_RETRY_AFTER && resendable?(e, resend_unanswered)

          sleep([requested, backoff(retries)].compact.max)
          retry
        end
      end

      private

      # Whether a failure leaves a request safe to send again
      #
      # A ServerError or a RequestTimeout is an answer, which says the API failed to act on the request. A NetworkError
      # says the API never received it only when its cause is among UNSENT_ERRORS; any other may have come after the
      # API answered. None of them says so when a callback raised it, rather than the API.
      #
      # @api private
      # @param error [Error] the error the request raised
      # @param resend_unanswered [Boolean] whether a request the API may have answered is sent again
      # @return [Boolean] true if the request may be sent again
      def resendable?(error, resend_unanswered)
        return false if CallbackError.untagged?(error)

        resend_unanswered || error.is_a?(HTTPError) || UNSENT_ERRORS.any? { |unsent| error.cause.is_a?(unsent) }
      end

      # The seconds a response asks a request to wait before it is sent again
      #
      # A request that never got a response, which raised a NetworkError, asks for no wait, and neither does a
      # response that carries no Retry-After header.
      #
      # @api private
      # @param error [Error] the error the request raised
      # @return [Integer, nil] the seconds the response asks for, or nil if it asks for none
      def retry_after(error)
        error.retry_after if error.is_a?(HTTPError)
      end

      # The seconds to wait before a retry
      #
      # The wait doubles with each retry until it reaches MAX_RETRY_AFTER, and a random share of up to half of it is
      # taken off. The share is what keeps the requests apart: a failure of the API fails every request in flight at
      # once, and requests that waited the same time would be sent again together, to fail together once more. The
      # cap keeps a client given many retries from sleeping for longer than a response may ask it to, as the waits
      # of a doubling without end would: the tenth retry would otherwise wait over eight minutes.
      #
      # @api private
      # @param retries [Integer] the number of the retry, counting from one
      # @return [Float] the seconds to wait
      def backoff(retries)
        wait = [INITIAL_WAIT << (retries - 1), MAX_RETRY_AFTER].min
        wait - (rand * wait / 2)
      end
    end
    private_constant :RetryHandler
  end
end
