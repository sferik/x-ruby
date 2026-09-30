# frozen_string_literal: true

require "net/http"
require "socket"
require_relative "errors/http_error"
require_relative "errors/network_error"
require_relative "errors/request_timeout"
require_relative "errors/server_error"
require_relative "setting_validator"

module X
  module Core
    # Run a request that is safe to send twice, sending it again after a failure
    #
    # A client sends no POST again, since the API may have acted on one whose answer never arrived, and sends no
    # request again after its answer failed to arrive, since the API bills a read it answered whether or not the
    # answer arrived. A request that is safe to send again anyway, such as the chunk of an upload, which names the
    # segment it is appended at and which the API bills nothing for, is sent again with this: after a ServerError, a
    # RequestTimeout, or a NetworkError of any kind, up to max_retries times, as a client sends an idempotent request
    # again, after the wait a response asks for, or a backoff that doubles with each retry and is cut short at
    # random, so that the requests one failure ended are not sent again together. A response that asks to be left
    # alone for longer than a minute raises at once. The block must build its request anew each time, so that each
    # attempt is signed afresh, as a request of a client is.
    #
    # Wrap a request the client sends no more than once, such as a POST: a client sends a GET, a PUT, or a DELETE
    # again itself, so one wrapped in this is sent max_retries times more for each time this sends it, nine times in
    # all with the defaults, rather than three. It is public, although the rest of X::Core is internal to x-core, since
    # a caller who knows a POST to be safe to send twice sends it with this, as x-uploader sends the chunks of an upload.
    #
    # @api public
    # @param max_retries [Integer] the maximum number of times to send the request again, as X::Client takes it
    # @yield sends the request
    # @return [Object] what the block returns
    # @raise [ArgumentError] if the maximum number of retries is not an Integer of at least 0
    # @raise [NetworkError] if the request fails once more than the retries allow
    # @raise [ServerError, RequestTimeout] if the API fails to answer once more than the retries allow, or asks for a
    #   wait longer than a minute
    # @example Append a chunk of an upload, again after a failure, as often as the client sends a request again
    #   X::Core.with_retries(max_retries: client.max_retries) { client.post("media/upload/1/append", body, headers:) }
    def self.with_retries(max_retries: RetryHandler::DEFAULT_MAX_RETRIES, &)
      RetryHandler.new(max_retries:).handle(idempotent: true, resend_unanswered: true, &)
    end

    # Sends a request again after the API failed to answer it, or after its answer never arrived
    #
    # Internal to x-core: Client retries with it, and takes max_retries, and Core.with_retries sends a request again
    # with it that a client sends no more than once, as it does any POST.
    #
    # @api private
    class RetryHandler
      # Default maximum number of retries, which sends an idempotent request twice more before it raises
      DEFAULT_MAX_RETRIES = 2
      # Seconds to wait before the first retry, doubled for each retry after
      INITIAL_WAIT = 1
      # The longest wait a response may ask for that a request waits out before it is sent again; a response that
      # asks to be left alone for longer raises at once, rather than hold a caller for minutes on end
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
      # twice as long before each retry after, or for as long as the response asks when it carries a Retry-After
      # header, whichever is longer. A response that asks to be left alone for longer than MAX_RETRY_AFTER raises
      # at once, since waiting it out would hold the caller for minutes. Only an idempotent request is retried: the
      # API may have acted on a POST whose answer never arrived, so sending that again could post twice. The block
      # must build its request anew each time, so that each attempt is signed afresh.
      #
      # A NetworkError is retried only when the request never left: a request that timed out reading its response,
      # or whose connection dropped once it was written, may have been answered, and the API bills a read it answered
      # whether or not the answer arrived, so sending it again could bill it again. resend_unanswered retries those
      # too, for a request the API bills nothing for, such as the chunk of an upload.
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
      # API answered.
      #
      # @api private
      # @param error [Error] the error the request raised
      # @param resend_unanswered [Boolean] whether a request the API may have answered is sent again
      # @return [Boolean] true if the request may be sent again
      def resendable?(error, resend_unanswered)
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
      # The wait doubles with each retry, and a random share of up to half of it is taken off. The share is what
      # keeps the requests apart: a failure of the API fails every request in flight at once, and requests that
      # waited the same time would be sent again together, to fail together once more.
      #
      # @api private
      # @param retries [Integer] the number of the retry, counting from one
      # @return [Float] the seconds to wait
      def backoff(retries)
        wait = INITIAL_WAIT << (retries - 1)
        wait - (rand * wait / 2)
      end
    end
  end
end
