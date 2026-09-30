# frozen_string_literal: true

require "simple_oauth"
require_relative "errors/authorization_error"
require_relative "errors/unauthorized"
require_relative "oauth2_tokens"
require_relative "origin"
require_relative "refresh_reporter"
require_relative "setting_validator"
require_relative "token_endpoint"

module X
  module Core
    # How an OAuth2Authenticator refreshes its tokens, before a request and after a rejection, included into it
    #
    # Processes that share the tokens of a user read the store they share with load_tokens before a refresh, and take
    # the tokens there in place of their own when those hold another refresh token, which another process issued
    # by a refresh of its own. The tokens taken are copied, and never recorded as the latest a refresh issued, so the
    # RefreshReporter passes them to no on_token_refresh: they came from the store.
    #
    # Internal to x-core: the methods are private, and a client calls retrying_rejected_token with __send__.
    #
    # @api private
    module OAuth2Refresh
      # The message raised when the token endpoint describes no reason for the failure
      DEFAULT_ERROR_MESSAGE = "Token refresh failed"
      private_constant :DEFAULT_ERROR_MESSAGE
      # Seconds after a refresh in which a rejection of the access token it issued refreshes nothing
      FRESH_TOKEN_SECONDS = 60
      private_constant :FRESH_TOKEN_SECONDS
      # The message of the error raised for load_tokens that returns what is not tokens
      NOT_TOKENS = "load_tokens must return an X::OAuth2Tokens, or nil for none in the store, not a %s. Build the " \
        "tokens from what the store holds with X::OAuth2Tokens.new"
      private_constant :NOT_TOKENS
      # The error codes of a refresh X refuses for a refresh token it no longer accepts, as one another process spent
      REFUSED_REFRESH_TOKEN = %w[invalid_request invalid_grant].freeze
      private_constant :REFUSED_REFRESH_TOKEN

      private

      # Initialize the lock, the reporter, and the loader of the refreshes
      # @api private
      # @param load_tokens [#call, nil] the callable that returns the OAuth2Tokens in the store, or nil for none
      # @return [void]
      # @raise [ArgumentError] if load_tokens is neither nil nor responds to call
      def initialize_refresh(load_tokens)
        @load_tokens = SettingValidator.callable!(:load_tokens, load_tokens)
        @mutex = Mutex.new
        @reporter = RefreshReporter.new
      end

      # Refresh the access token if it has expired, over a connection
      #
      # An authenticator that holds no refresh token refreshes nothing, and sends the token it holds.
      #
      # @api private
      # @param connection [Core::Connection] the connection to send the refresh over
      # @param client [Client, nil] the client whose request refreshes, or nil for none
      # @return [void]
      # @raise [AuthorizationError] if X refuses to refresh the token
      # @raise [HTTPError, InvalidResponse] if the token endpoint limits the rate of the request or fails to answer,
      #   as a server error, a redirect, or the page of a proxy says
      # @raise [TokenReportFailed] if on_token_refresh raises for the tokens of the refresh
      def refresh_expired_token(connection, client = nil)
        tokens = @mutex.synchronize { renew(connection) if refresh_token && token_expired? }
        report_refresh(tokens, client) if tokens
      end

      # Refresh a rejected access token, unless it was already replaced or just issued
      #
      # Requests that were sent with the same token, and rejected together, refresh it once between them. A token
      # issued by a refresh less than FRESH_TOKEN_SECONDS ago has not expired, so the API rejects it for another
      # reason, which a refresh would not change: it is not refreshed, and the rejection is raised, rather than spend
      # a refresh token on each request an endpoint that always rejects the token answers. An authenticator that holds no
      # refresh token refreshes nothing, so the rejection is raised.
      #
      # @api private
      # @param rejected_token [String] the access token the API rejected
      # @param connection [Core::Connection] the connection to send the refresh over
      # @param client [Client, nil] the client whose request the API rejected, or nil for none
      # @return [Boolean] true if the access token is no longer the one rejected
      # @raise [AuthorizationError] if X refuses to refresh the token
      # @raise [HTTPError, InvalidResponse] if the token endpoint limits the rate of the request or fails to answer,
      #   as a server error, a redirect, or the page of a proxy says
      # @raise [TokenReportFailed] if on_token_refresh raises for the tokens of the refresh
      def refresh_rejected_token!(rejected_token, connection, client = nil)
        tokens, replaced = @mutex.synchronize do
          [(renew(connection) if refresh_token && access_token.eql?(rejected_token) && !fresh?), !access_token.eql?(rejected_token)]
        end
        report_refresh(tokens, client) if tokens
        replaced
      end

      # Run a request, again if the API rejects a token that a refresh replaces
      #
      # X rejects an expired access token with 401 Unauthorized, which an authenticator that does not know when
      # its token expires learns only from the rejection. A 401 from another origin than the one the token is sent to
      # answers a request that carried no token, whether it named that origin or was redirected there, so it refreshes
      # nothing: X accepts a refresh token once, and a refresh would replace the tokens for a rejection of no token.
      #
      # A token that has expired is refreshed before the request, and one the API rejects after it, over the
      # connection given, which is the one of the client that sends the request: the copies of a client share its
      # authenticator, and a copy given another proxy, other timeouts, or other debug output refreshes the tokens it
      # shares with them, as it sends its requests with them.
      #
      # Internal to x-core: Client runs each request it sends with an OAuth 2.0 authenticator through it, and calls it
      # with __send__, since it is private.
      #
      # @api private
      # @param origin [URI::Generic] a URI of the origin the token is sent to, such as the base URL of a client
      # @param connection [Core::Connection] the connection to send a refresh over
      # @param client [Client, nil] the client that sends the request, which TokenReportFailed holds, or nil for none
      # @yield runs the request
      # @return [Object] what the block returns
      # @raise [Unauthorized] if the request is rejected again, or by another origin, or a refresh does not replace
      #   the access token
      # @raise [TokenReportFailed] if on_token_refresh raises for the tokens of a refresh, with the tokens and client
      def retrying_rejected_token(origin, connection, client = nil)
        refresh_expired_token(connection, client)
        token = access_token
        begin
          yield
        rescue Unauthorized => e
          raise unless Origin.answered?(e, origin) && refresh_rejected_token!(token, connection, client)

          yield
        end
      end

      # Take the tokens in the store, or else refresh, holding the lock
      #
      # Tokens taken from the store whose access token has not expired are sent as they are, and the others refreshed
      # with the refresh token there.
      #
      # @api private
      # @param connection [Core::Connection] the connection to send the refresh over
      # @return [OAuth2Tokens, nil] the tokens the refresh issued, or those it took from the store in place of a
      #   refusal, or nil for tokens taken from the store that need no refresh
      # @raise [AuthorizationError] if X refuses to refresh the token
      # @raise [HTTPError, InvalidResponse] if the token endpoint limits the rate of the request or fails to answer,
      #   as a server error, a redirect, or the page of a proxy says
      def renew(connection)
        refresh(connection) unless adopt_stored_tokens && !token_expired?
      end

      # Refresh the access token, holding the lock
      #
      # It is called for an authenticator that holds a refresh token alone, which a refresh never takes away. A
      # refresh X refuses for a refresh token it no longer accepts reads the store again, and takes the tokens there,
      # if they hold another refresh token, in place of raising: another process spent the refresh token first.
      #
      # @api private
      # @param connection [Core::Connection] the connection to send the refresh over
      # @return [OAuth2Tokens] the tokens the refresh issued, once the authenticator holds them, or those it took from
      #   the store in place of a refusal
      # @raise [AuthorizationError] if X refuses to refresh the token, and the store holds no other
      # @raise [HTTPError, InvalidResponse] if the token endpoint limits the rate of the request or fails to answer,
      #   as a server error, a redirect, or the page of a proxy says
      def refresh(connection)
        held = refresh_token #: String
        update_tokens(TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token: held), connection:))
        @spent_refresh_token = held
        issued = refresh_token #: String
        @reporter.issued(OAuth2Tokens.new(access_token:, refresh_token: issued, expires_at:))
      rescue SimpleOAuth::OAuth2::Error => e
        adopt_in_place_of(e)
      end

      # Take the stored tokens in place of a refused refresh, or raise the refusal
      # @api private
      # @param error [SimpleOAuth::OAuth2::Error] the refusal
      # @return [OAuth2Tokens] a copy of the tokens taken
      # @raise [AuthorizationError] if X refused anything but the refresh token, or the store holds no other
      def adopt_in_place_of(error)
        adopted = adopt_stored_tokens if REFUSED_REFRESH_TOKEN.include?(error.code)
        adopted or raise AuthorizationError.from(error, DEFAULT_ERROR_MESSAGE), cause: error.cause
      end

      # Take the stored tokens, if they hold another refresh token
      #
      # Tokens that hold the refresh token the authenticator holds, or the one its last refresh spent, are its own,
      # as the store holds them until on_token_refresh has stored the tokens of that refresh, which it is passed once
      # the lock is released, so they are not taken. The age of the access token taken is unknown, so it is not fresh.
      #
      # @api private
      # @return [OAuth2Tokens, nil] a copy of the tokens taken, or nil if the store holds none, or none of another's
      def adopt_stored_tokens
        stored = stored_tokens or return
        return if [refresh_token, @spent_refresh_token].include?(stored.refresh_token)

        @refreshed_at = nil
        @access_token = stored.access_token
        @refresh_token = stored.refresh_token
        @expires_at = stored.expires_at
        OAuth2Tokens.new(**stored.to_h)
      end

      # The tokens in the store the tokens of the user are shared through
      #
      # They are read with the load_tokens of the authenticator, or else with the load_tokens of a client that
      # authenticates with it. The error names the class of what load_tokens returned, rather than inspect it, since a
      # Hash of the tokens would show them.
      #
      # @api private
      # @return [OAuth2Tokens, nil] the tokens, or nil for none in the store, or no load_tokens to read it with
      # @raise [TypeError] if load_tokens returns neither OAuth2Tokens nor nil
      def stored_tokens
        load_tokens = @load_tokens || clients.keys.filter_map(&:load_tokens).first
        stored = load_tokens&.call
        raise TypeError, format(NOT_TOKENS, stored.class) unless stored.nil? || stored.is_a?(OAuth2Tokens)

        stored
      end

      # Pass the tokens of a refresh to its callables, once the lock is released
      #
      # A callable can make a request of its own, such as looking up the user whose tokens it stores, which asks this
      # authenticator for a header and so takes the lock again. The refreshes are reported in the order they were
      # made, and one already replaced is not reported; see {Core::RefreshReporter}.
      #
      # @api private
      # @param tokens [OAuth2Tokens] the tokens the refresh issued
      # @param client [Client, nil] the client whose request refreshed, which TokenReportFailed holds, or nil for none
      # @return [void]
      # @raise [TokenReportFailed] if on_token_refresh raises for the tokens, with the tokens and client
      def report_refresh(tokens, client) = @reporter.report(tokens, client)

      # Update tokens from the response
      # @api private
      # @param token [SimpleOAuth::OAuth2::Token] the token the endpoint returned
      # @return [void]
      def update_tokens(token)
        @refreshed_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @access_token = token.access_token
        @refresh_token = token.refresh_token if token.refresh_token
        @expires_at = token.expires_at
      end

      # Check whether a refresh issued the access token within FRESH_TOKEN_SECONDS
      #
      # A token the authenticator was given, rather than refreshed, may be of any age, so it is not fresh.
      #
      # @api private
      # @return [Boolean] true if a refresh issued the token less than FRESH_TOKEN_SECONDS ago
      def fresh?
        refreshed_at = @refreshed_at
        !refreshed_at.nil? && Process.clock_gettime(Process::CLOCK_MONOTONIC) - refreshed_at < FRESH_TOKEN_SECONDS
      end
    end
  end
end
