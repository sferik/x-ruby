# frozen_string_literal: true

require "simple_oauth"
require_relative "errors/authorization_error"
require_relative "errors/unauthorized"
require_relative "oauth2_tokens"
require_relative "origin"
require_relative "token_endpoint"

module X
  module Core
    # How an OAuth2Authenticator refreshes its tokens, before a request and after a rejection, included into it
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

      private

      # Refresh the access token if it has expired, over a connection
      #
      # An authenticator that holds no refresh token refreshes nothing, and sends the token it holds.
      #
      # @api private
      # @param connection [Core::Connection] the connection to send the refresh over
      # @return [void]
      # @raise [AuthorizationError] if X refuses to refresh the token
      # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
      def refresh_expired_token(connection)
        tokens = @mutex.synchronize { refresh(connection) if refresh_token && token_expired? }
        report_refresh(tokens) if tokens
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
      # @return [Boolean] true if the access token is no longer the one rejected
      # @raise [AuthorizationError] if X refuses to refresh the token
      # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
      def refresh_rejected_token!(rejected_token, connection)
        tokens, replaced = @mutex.synchronize do
          [(refresh(connection) if refresh_token && access_token.eql?(rejected_token) && !fresh?), !access_token.eql?(rejected_token)]
        end
        report_refresh(tokens) if tokens
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
      # @yield runs the request
      # @return [Object] what the block returns
      # @raise [Unauthorized] if the request is rejected again, or by another origin, or a refresh does not replace
      #   the access token
      def retrying_rejected_token(origin, connection)
        refresh_expired_token(connection)
        token = access_token
        begin
          yield
        rescue Unauthorized => e
          raise unless Origin.answered?(e, origin) && refresh_rejected_token!(token, connection)

          yield
        end
      end

      # Refresh the access token, holding the lock
      #
      # It is called for an authenticator that holds a refresh token alone, which a refresh never takes away.
      #
      # @api private
      # @param connection [Core::Connection] the connection to send the refresh over
      # @return [OAuth2Tokens] the tokens the refresh issued, once the authenticator holds them
      # @raise [AuthorizationError] if X refuses to refresh the token
      # @raise [TooManyRequests, ServerError] if the token endpoint limits the rate of the request or fails to answer
      def refresh(connection)
        held = refresh_token #: String
        update_tokens(TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token: held), connection:))
        issued = refresh_token #: String
        @reporter.issued(OAuth2Tokens.new(access_token:, refresh_token: issued, expires_at:))
      rescue SimpleOAuth::OAuth2::Error => e
        raise AuthorizationError.from(e, DEFAULT_ERROR_MESSAGE), cause: e.cause
      end

      # Pass the tokens of a refresh to its callables, once the lock is released
      #
      # A callable can make a request of its own, such as looking up the user whose tokens it stores, which asks this
      # authenticator for a header and so takes the lock again. The refreshes are reported in the order they were
      # made, and one already replaced is not reported; see {Core::RefreshReporter}.
      #
      # @api private
      # @param tokens [OAuth2Tokens] the tokens the refresh issued
      # @return [void]
      def report_refresh(tokens) = @reporter.report(tokens)

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
