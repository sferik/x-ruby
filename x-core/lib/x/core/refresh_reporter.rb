# frozen_string_literal: true

require "monitor"
require_relative "errors/token_report_failed"

module X
  module Core
    # Reports the refreshes of an OAuth 2.0 authenticator to the callables that store their tokens
    #
    # The refreshes are reported one at a time, in the order they were made, and a refresh another has replaced by
    # the time it is reported is not reported at all: a callable that stores the tokens of a refresh as another
    # stores the tokens that replaced them would otherwise overwrite them with a refresh token X no longer accepts.
    # A callable that raises keeps none of the others from being passed the tokens, and once every one has been,
    # TokenReportFailed is raised, which holds the tokens, since the refresh token they replaced is spent, with the
    # first error as its cause. A Timeout::Error is a failure of a callable too, even one Timeout.timeout raises with
    # its class around the request, since the error that holds the tokens is the only place left to find them; one it
    # raises without a class is not a StandardError until it leaves the block, so it is raised as it is.
    #
    # The lock it reports under is reentrant, so a callable can make a request of its own, such as looking up the
    # user whose tokens it stores, which may refresh and report again on the same thread.
    #
    # @api private
    class RefreshReporter
      # The message of the error raised when a callable raised for the tokens of a refresh
      REPORT_FAILED = "The tokens were refreshed, but save_tokens raised for them"
      # The fiber-local key of a callable that a gem extending a client sets, which the callables are run inside
      #
      # x-streams sets it while a stream runs, and x-uploads in each thread of a chunked upload, so that a stop of
      # the stream, or of the upload, waits for save_tokens to store the tokens of a refresh, rather than cutting it
      # short and leaving the store with a refresh token X no longer accepts. The callable is passed a block, which it
      # runs and whose result it returns.
      GUARD = :x_core_refresh_report_guard

      # Initialize a reporter with no refresh to report
      # @api private
      # @return [RefreshReporter] a new reporter
      def initialize
        @monitor = Monitor.new
      end

      # Record the tokens of a refresh as the latest, while the refresh holds its lock
      # @api private
      # @param tokens [OAuth2Tokens] the tokens the refresh issued
      # @return [OAuth2Tokens] the tokens
      def issued(tokens) = (@latest = tokens)

      # Pass each refresh to the callables another reads
      # @api private
      # @param hooks [#call] a callable that returns the callables to pass each refresh, read at each refresh
      # @return [#call] the callable
      def to(hooks) = (@hooks = hooks)

      # Pass the tokens of a refresh to the callables, unless a later one replaced them
      # @api private
      # @param tokens [OAuth2Tokens] the tokens the refresh issued
      # @param client [Client, nil] the client whose request refreshed, which the error holds, or nil for none
      # @return [void]
      # @raise [TokenReportFailed] if a callable raises, with the tokens and client, once every one has been passed them
      def report(tokens, client)
        @monitor.synchronize { guarded { pass(tokens, client) } if tokens.equal?(@latest) }
      end

      private

      # Run a block inside the guard of the fiber, if a gem extending the client set one
      # @api private
      # @yield passes the tokens to the callables
      # @return [void]
      def guarded(&) = (guard = Thread.current[GUARD]) ? guard.call(&) : yield

      # Pass tokens to each callable, raising for the first error once all have run
      # @api private
      # @param tokens [OAuth2Tokens] the tokens the refresh issued
      # @param client [Client, nil] the client whose request refreshed, or nil for none
      # @return [void]
      # @raise [TokenReportFailed] if a callable raises, with the tokens and client, and the first error as its cause
      def pass(tokens, client)
        hooks = @hooks
        return unless hooks

        errors = hooks.call.filter_map do |hook|
          hook.call(tokens)
          nil
        rescue => e
          e
        end
        raise TokenReportFailed.new(REPORT_FAILED, client:, tokens:), cause: errors.first unless errors.empty?
      end
    end
    private_constant :RefreshReporter
  end
end
