# frozen_string_literal: true

require "x/core"
require_relative "callback_error"
require_relative "stopper"
require_relative "stream_error"
require_relative "validator"

module X
  module Streams
    # Reconnects a stream that drops, backing off as X recommends
    #
    # A stream that ends, loses its connection, or cannot open one, as when the connection is refused, or that X
    # disconnects with an operational-disconnect, reconnects at once, then after a delay that grows by a quarter
    # second each attempt, up to 16 seconds. A server error, a 408 Request Timeout, a 409 Conflict, or a line that is
    # not JSON backs off from 5 seconds, doubling each attempt, up to 320 seconds, and waits longer when the response
    # asks for longer with a Retry-After header, as the retries of a client do; one that asks for longer than
    # max_rate_limit_wait raises at once, as a rate limit that resets later does. A rate limit backs off from a minute,
    # doubling each attempt, as X asks, and waits longer when the limit resets later; one that would wait longer than
    # max_rate_limit_wait raises at once, rather than hold the stream closed for hours, as a limit on the requests of a
    # day would, or keep asking for a connection X keeps refusing. Each of the three backs off on a count of its own,
    # so that the dropped connections before a server error do not lengthen the wait after it.
    #
    # An object, or the keep-alive X sends every 20 seconds, read from a connection that has been open for a minute
    # starts every count over, so that a stream that is quiet but connected is not taken for one that keeps failing,
    # and one that drops after hours reconnects at once. One read from a connection younger than that starts none of
    # them over, so a stream whose connections each deliver an object and drop, as those of a server that is failing
    # do, backs off further with each, and is given up on after max_reconnects of them, rather than reconnected at
    # once without end, which would spend the connections X allows a stream in a window.
    #
    # A connection whose certificate does not verify raises at once rather than reconnect, as a certificate that did
    # not verify once will not the next time either, and reconnects are unlimited by default, so it would otherwise
    # reconnect every 16 seconds for as long as the stream runs. Other errors of the network reconnect however long
    # they last, as a host that does not resolve does, since most pass.
    #
    # Before each wait it passes the error that dropped the stream and the seconds it waits to on_reconnect, whose
    # error stops the stream, as an error of the consumer does.
    #
    # Internal to x-streams: StreamingClient reconnects with it, max_reconnects and on_reconnect are set on the
    # streaming client, which checked them, and max_rate_limit_wait is the client's, which the client checked when it
    # was built.
    #
    # @api private
    class ReconnectHandler
      # Default maximum number of reconnects in a row, which is unlimited, since a stream is meant to run until stopped
      DEFAULT_MAX_RECONNECTS = Float::INFINITY
      # Seconds the wait grows by after each dropped connection
      NETWORK_BACKOFF_STEP = 0.25
      # Longest wait after a dropped connection, in seconds
      MAX_NETWORK_BACKOFF = 16
      # First wait after a server error, in seconds
      HTTP_BACKOFF_START = 5
      # Longest wait after a server error, in seconds
      MAX_HTTP_BACKOFF = 320
      # First wait after a rate limit, in seconds, for a limit that does not say when it resets
      RATE_LIMIT_BACKOFF_START = 60
      # Seconds a connection has been open for before what is read from it starts the counts over, three times the
      # interval of the keep-alive X sends, so that a stream reconnects at once no more than once a minute
      STABLE_CONNECTION = 60
      # The errors a stream reconnects after, which come from the server or the connection rather than the request
      RECONNECTABLE_ERRORS = [NetworkError, ServerError, RequestTimeout, Conflict, TooManyRequests, InvalidResponse].freeze
      # The counts a stream starts with, and starts over at: the reconnects in a row, which max_reconnects limits, and
      # the reconnects after each kind of error, which the wait before the next reconnect after that kind grows with
      FIRST_STATE = {reconnects: 0, network: 0, http: 0, rate_limit: 0}.freeze
      # What OpenSSL says of a certificate that does not verify, such as one that expired, is signed by an authority
      # the system does not trust, or names another host
      UNVERIFIED_CERTIFICATE = "certificate verify failed"

      # Raised in place of an error the consumer of a stream raised, which is its cause, so that the stream stops
      ConsumerError = Class.new(StandardError) #: singleton(StandardError)
      private_constant :ConsumerError

      # The longest a stream waits for a rate limit to reset, in seconds
      # @api private
      # @return [Integer, Float] the maximum wait in seconds
      # @example Read the maximum wait
      #   handler.max_rate_limit_wait # => 900
      attr_reader :max_rate_limit_wait

      # The most reconnects in a row without a connection that stays open for a minute
      # @api private
      # @return [Integer, Float] the maximum number of reconnects, or Float::INFINITY for no limit
      # @example Read the maximum reconnects
      #   handler.max_reconnects # => 5
      attr_reader :max_reconnects

      # Initialize a new reconnect handler
      #
      # @api private
      # @param max_reconnects [Integer, Float] the maximum number of reconnects in a row, or Float::INFINITY
      # @param max_rate_limit_wait [Integer, Float] the longest wait for a rate limit to reset, in seconds
      # @param on_reconnect [#call, nil] the callable passed the error that dropped the stream and the seconds the
      #   handler waits, before each wait to reconnect, or nil for none
      # @return [ReconnectHandler] a new instance
      # @raise [ArgumentError] if the maximum number of reconnects is neither an Integer of at least 0 nor
      #   Float::INFINITY
      # @example Create a reconnect handler
      #   handler = X::Streams::ReconnectHandler.new(max_reconnects: 5)
      def initialize(max_reconnects: DEFAULT_MAX_RECONNECTS, max_rate_limit_wait: Client::DEFAULT_MAX_RATE_LIMIT_WAIT, on_reconnect: nil)
        @max_reconnects = Validator.count_or_infinity!(:max_reconnects, max_reconnects)
        @max_rate_limit_wait = max_rate_limit_wait
        @on_reconnect = on_reconnect
      end

      # Run a stream, running it again whenever it drops
      #
      # An error raised by the consumer stops the stream, even one that would otherwise reconnect, and reaches the
      # caller, as does an error raised by on_reconnect, which is raised from the rescue of the error that dropped the
      # stream, an error raised by the on_response of the client, or by the class an object is parsed into, which the
      # stream tags as a CallbackError, so that one a stream reconnects after, such as an X::ServerError of a request
      # on_response made, is not taken for the stream's own, and any error that is not one a stream reconnects after,
      # such as the StreamError of a line that holds errors other than a disconnect. The stream is run again with while
      # rather than Kernel#loop, which rescues StopIteration, so that a StopIteration raised from an Enumerator that has
      # run out, wherever it is raised, reaches the caller too, rather than end the stream without a word.
      #
      # @api private
      # @param consumer [Proc] the block that receives each object
      # @yield [deliver, alive] runs the stream once
      # @yieldparam deliver [Proc] the block to pass each object to, which passes it on to the consumer
      # @yieldparam alive [Proc] the callable to call for each keep-alive the stream reads
      # @return [nil] once the stream returns rather than raise
      # @raise [NetworkError, ServerError, RequestTimeout, Conflict, TooManyRequests, InvalidResponse, StreamError] if
      #   the stream fails with no reconnects left
      # @raise [TooManyRequests] if a rate limit asks the stream to wait longer than max_rate_limit_wait, or the project
      #   has reached its usage cap
      # @raise [ServerError, RequestTimeout, Conflict] if its Retry-After header asks the stream to wait longer than
      #   max_rate_limit_wait
      # @raise [NetworkError] if the certificate of the connection does not verify, with reconnects left or not
      # @example Reconnect a stream
      #   handler.handle(->(post) { puts post }) { |deliver, alive| read_stream(on_keep_alive: alive, &deliver) }
      def handle(consumer, &stream)
        state = FIRST_STATE.dup
        while run_once(stream, consumer, state); end
      rescue ConsumerError => e
        raise cause_of(e)
      rescue CallbackError => e
        raise e.error
      end

      private

      # Run a stream once, waiting for the next reconnect when it drops or ends
      #
      # A stream ends by raising, as StreamingClient raises a NetworkError for one the server ended, since X holds a
      # stream open until it drops it, so each reconnect follows an error, which on_reconnect is passed. A stream that
      # returns rather than raise is done, and is not run again. The reconnect is waited for in the rescue of that
      # error, so an error on_reconnect raises is not rescued as one of the stream, even an X::NetworkError, which
      # would otherwise be reconnected after, and reaches the caller as it was raised.
      #
      # Each object and keep-alive the stream reads starts the counts over once the connection has been open for
      # STABLE_CONNECTION seconds, which are counted from when the stream is run, on a clock that never runs back.
      #
      # @api private
      # @param stream [Proc] runs the stream once
      # @param consumer [Proc] the block that receives each object
      # @param state [Hash{Symbol => Integer}] the counts of reconnects, for one call to handle
      # @return [Boolean] true to run the stream again, or false once it returned
      # @raise [NetworkError, ServerError, RequestTimeout, Conflict, TooManyRequests, InvalidResponse, StreamError] if
      #   the stream fails with no reconnects left
      def run_once(stream, consumer, state)
        opened_at = now
        alive = -> { state.replace(FIRST_STATE) if now - opened_at >= STABLE_CONNECTION }
        stream.call(delivery_to(consumer, alive), alive)
        false
      rescue *RECONNECTABLE_ERRORS, StreamError => e
        raise unless reconnectable?(e)
        raise if out_of_reconnects?(e, state)

        true
      end

      # Check whether a stream reconnects after an error
      #
      # A stream reconnects after a StreamError only when each of its problems is an operational-disconnect, after a
      # TooManyRequests unless it is the usage cap of the project, which lasts until the month ends, and after a
      # NetworkError unless it is a certificate that does not verify, which x-core raises with the
      # OpenSSL::SSL::SSLError as its cause.
      #
      # @api private
      # @param error [StandardError] the error that dropped the stream
      # @return [Boolean] true unless the error is a StreamError of any problem but a disconnect, the usage cap, or a
      #   certificate that does not verify
      def reconnectable?(error)
        case error
        when StreamError then error.problems.all?(&:disconnect?)
        when TooManyRequests then !error.problem&.usage_capped?
        when NetworkError then !unverified_certificate?(error.cause)
        else true
        end
      end

      # Check whether the cause of a NetworkError is a certificate that does not verify
      # @api private
      # @param cause [Exception, nil] the cause of the error
      # @return [Boolean] true if the cause is an OpenSSL::SSL::SSLError of a certificate that does not verify
      def unverified_certificate?(cause) = cause.is_a?(OpenSSL::SSL::SSLError) && cause.message.include?(UNVERIFIED_CERTIFICATE)

      # The error a consumer raised, which a consumer error stands in for
      # @api private
      # @param error [ConsumerError] the error raised in its place
      # @return [StandardError] the error the consumer raised
      def cause_of(error)
        error.cause #: StandardError
      end

      # Check whether the reconnects are spent, waiting for the next if not
      # @api private
      # @param error [StandardError] the error that dropped the stream
      # @param state [Hash{Symbol => Integer}] the counts of reconnects, for one call to handle
      # @return [Boolean] true if no reconnects remain, or false once it has waited for the next
      def out_of_reconnects?(error, state)
        return true if count(state, :reconnects) > max_reconnects

        wait = backoff(error, state)
        announce(error, wait)
        Stopper.pausing(wait) { |seconds| sleep(seconds) }
        false
      end

      # Pass on_reconnect the error that dropped the stream and the wait to reconnect
      # @api private
      # @param error [StandardError] the error that dropped the stream
      # @param wait [Integer, Float] the seconds to wait
      # @return [void]
      def announce(error, wait) = @on_reconnect&.call(error, wait)

      # The seconds of a clock that never runs back
      #
      # The clock of the system runs back when it is set, which would make a connection younger than it is.
      #
      # @api private
      # @return [Float] the seconds
      def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      # A block that passes an object to the consumer and starts the counts over
      #
      # The counts start over only for a connection open long enough, which restart sees to.
      #
      # @api private
      # @param consumer [Proc] the block that receives each object
      # @param restart [Proc] the callable that starts the counts of reconnects over, for a connection open long enough
      # @return [Proc] the block
      def delivery_to(consumer, restart)
        lambda do |object|
          restart.call
          consumer.call(object)
        rescue
          raise ConsumerError
        end
      end

      # The wait before a reconnect, by the kind of error
      #
      # The wait grows with the count of reconnects after errors of the same kind, which this counts one more of.
      #
      # @api private
      # @param error [StandardError] the error that dropped the stream
      # @param state [Hash{Symbol => Integer}] the counts of reconnects, for one call to handle
      # @return [Float, Integer] the seconds to wait
      def backoff(error, state)
        case error
        when TooManyRequests then rate_limit_backoff(error, count(state, :rate_limit))
        when HTTPError then http_backoff(error, count(state, :http))
        else network_backoff(count(state, :network))
        end
      end

      # Count one more reconnect
      # @api private
      # @param state [Hash{Symbol => Integer}] the counts of reconnects, for one call to handle
      # @param name [Symbol] the name of the count
      # @return [Integer] the count, counting this reconnect
      def count(state, name) = state[name] = state.fetch(name) + 1

      # The wait before a reconnect after a rate limit, at least until it resets
      #
      # X asks a stream refused for a rate limit to back off from RATE_LIMIT_BACKOFF_START, doubling each attempt with
      # no cap, so a limit that resets sooner still waits that long, one that resets later waits until it does, and a
      # stream X keeps refusing raises once the wait passes max_rate_limit_wait.
      #
      # @api private
      # @param error [TooManyRequests] the error the connection raised
      # @param reconnects [Integer] the number of the reconnect, counting from one
      # @return [Integer] the seconds to wait
      # @raise [TooManyRequests] the error, if the wait is longer than max_rate_limit_wait
      def rate_limit_backoff(error, reconnects)
        wait = [error.retry_after, RATE_LIMIT_BACKOFF_START << (reconnects - 1)].compact.max #: Integer
        raise if wait > max_rate_limit_wait

        wait
      end

      # The wait before a reconnect after a dropped connection
      # @api private
      # @param reconnects [Integer] the number of the reconnect, counting from one
      # @return [Float, Integer] the seconds to wait
      def network_backoff(reconnects) = [NETWORK_BACKOFF_STEP * (reconnects - 1), MAX_NETWORK_BACKOFF].min

      # The wait before a reconnect after a server error, a refusal, or a bad line
      #
      # A response that asks for a wait with a Retry-After header, as a 503 that names the time its endpoint is
      # expected back does, waits that long when it is longer than the backoff, as a request a client sends again
      # does. One that asks for longer than max_rate_limit_wait raises at once, as a rate limit that resets later does,
      # rather than hold the stream closed for longer than a client would wait for its requests; the backoff alone
      # never raises.
      #
      # @api private
      # @param error [HTTPError] the error the connection raised
      # @param reconnects [Integer] the number of the reconnect, counting from one
      # @return [Integer] the seconds to wait
      # @raise [HTTPError] the error, if it asks for a wait longer than max_rate_limit_wait
      def http_backoff(error, reconnects)
        requested = error.retry_after
        raise if requested.to_i > max_rate_limit_wait

        backoff = [HTTP_BACKOFF_START << (reconnects - 1), MAX_HTTP_BACKOFF].min
        [requested, backoff].compact.max #: Integer
      end
    end
    private_constant :ReconnectHandler
  end
end
