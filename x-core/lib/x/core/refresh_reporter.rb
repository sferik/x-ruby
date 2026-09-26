# frozen_string_literal: true

require "monitor"

module X
  module Core
    # Reports the refreshes of an OAuth 2.0 authenticator to the callables that store their tokens
    #
    # The refreshes are reported one at a time, in the order they were made, and a refresh another has replaced by
    # the time it is reported is not reported at all: a callable that stores the tokens of a refresh as another
    # stores the tokens that replaced them would otherwise overwrite them with a refresh token X no longer accepts.
    # A callable that raises keeps none of the others from being passed the tokens, and the first error is raised
    # once every one has been.
    #
    # The lock it reports under is reentrant, so a callable can make a request of its own, such as looking up the
    # user whose tokens it stores, which may refresh and report again on the same thread.
    #
    # @api private
    class RefreshReporter
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

      # Pass each refresh to the callables another reads, too
      # @api private
      # @param hooks [#call] a callable that returns the callables to pass each refresh, read at each refresh
      # @return [#call] the callable
      def also_to(hooks) = (@hooks = hooks)

      # Pass the tokens of a refresh to the callables, unless a later one replaced them
      # @api private
      # @param tokens [OAuth2Tokens] the tokens the refresh issued
      # @param hook [#call, nil] the callable the authenticator was built with
      # @return [void]
      def report(tokens, hook)
        @monitor.synchronize { pass(tokens, [hook].compact) if tokens.equal?(@latest) }
      end

      private

      # Pass tokens to each callable, raising the first error once all have run
      # @api private
      # @param tokens [OAuth2Tokens] the tokens the refresh issued
      # @param hooks [Array<#call>] the callables the authenticator was built with
      # @return [void]
      def pass(tokens, hooks)
        others = @hooks
        hooks.concat(others.call) if others
        errors = hooks.filter_map do |hook|
          hook.call(tokens)
          nil
        rescue => e
          e
        end
        raise errors.first unless errors.empty?
      end
    end
  end
end
