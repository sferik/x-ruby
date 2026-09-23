# frozen_string_literal: true

require_relative "oauth2_authenticator"

module X
  module Core
    # The OAuth 2.0 authenticator of a client, which its copies share, and the tokens it last refreshed, included into
    # Client
    # @api private
    module ClientTokenRefresh
      # The time the OAuth 2.0 access token expires, as last refreshed
      #
      # A refresh that reports no lifetime leaves it nil, rather than the time the client was given.
      #
      # @api public
      # @return [Time, nil] the expiration time, or nil if it is not known
      # @example Get the expiration time
      #   client.expires_at
      def expires_at
        current = oauth2_authenticator_in_use
        current ? current.expires_at : @expires_at
      end

      protected

      # Share an OAuth 2.0 authenticator that holds the same credentials
      #
      # A refresh by either client then reaches both. X accepts a refresh token once, so a copy that refreshed with
      # an authenticator of its own would leave the original client with a refresh token that no longer works. The
      # expiration time is a fact about the access token the two hold, so a copy given another sets it for both.
      #
      # @api private
      # @param other [Authenticator] the authenticator of the client this one was copied from
      # @param clients [ObjectSpace::WeakMap] the clients that share it, held weakly, which this client joins
      # @return [void]
      def share_authenticator(other, clients)
        current = oauth2_authenticator_in_use
        return unless current&.same_credentials?(other)

        shared = other #: OAuth2Authenticator
        shared.__send__(:update_expires_at, expires_at)
        @authenticator = shared
        @token_refresh_clients = clients
        clients[self] = true
      end

      # The OAuth 2.0 authenticator, if the client authenticates with one
      # @api private
      # @return [OAuth2Authenticator, nil] the authenticator or nil
      def oauth2_authenticator_in_use
        current = @authenticator
        current if current.is_a?(OAuth2Authenticator)
      end

      # The OAuth 2.0 authenticator of the client's credentials, if they form a set
      #
      # A copy of a client shares the authenticator of the client it was copied from, rather than the one this
      # builds, when the two hold the same credentials; see share_authenticator.
      #
      # @api private
      # @return [OAuth2Authenticator, nil] the OAuth 2.0 authenticator or nil
      def oauth2_authenticator
        client_id = @client_id
        access_token = @access_token
        refresh_token = @refresh_token
        return unless client_id && access_token && refresh_token

        new_oauth2_authenticator(client_id:, access_token:, refresh_token:)
      end

      private

      # The access token for OAuth authentication, as last refreshed
      #
      # It is private, as {ClientCredentials#api_key_secret} is. A hook given to on_token_refresh is passed the
      # authenticator, which holds the tokens of the refresh it reports.
      #
      # @api private
      # @return [String, nil] the access token for OAuth authentication
      def access_token
        current = oauth2_authenticator_in_use
        current ? current.access_token : @access_token
      end

      # The OAuth 2.0 refresh token, as last refreshed
      #
      # It is private for the reason {#access_token} is.
      #
      # @api private
      # @return [String, nil] the OAuth 2.0 refresh token
      def refresh_token
        current = oauth2_authenticator_in_use
        current ? current.refresh_token : @refresh_token
      end

      # Build an OAuth 2.0 authenticator whose refreshes reach the clients that share it
      #
      # It sends its token requests over the client's connection. A public client has no client secret, and refreshes
      # its tokens with its client ID alone.
      #
      # @api private
      # @param client_id [String] the OAuth 2.0 client ID
      # @param access_token [String] the OAuth 2.0 access token
      # @param refresh_token [String] the OAuth 2.0 refresh token
      # @return [OAuth2Authenticator] the OAuth 2.0 authenticator
      def new_oauth2_authenticator(client_id:, access_token:, refresh_token:)
        clients = @token_refresh_clients = ObjectSpace::WeakMap.new.tap { |registry| registry[self] = true }
        OAuth2Authenticator.new(client_id:, client_secret: @client_secret, access_token:, refresh_token:, expires_at: @expires_at,
          connection: @connection, on_token_refresh: ->(authenticator) { clients.keys.filter_map(&:on_token_refresh).uniq.each { |hook| hook.call(authenticator) } })
      end

      # Run a request, again if a refresh replaces an OAuth 2.0 token the API rejects
      #
      # Only a rejection by the origin of the base URL, which the token is sent to, refreshes it; see {Origin}.
      #
      # @api private
      # @yield runs the request
      # @return [Object] what the block returns
      def refreshing_rejected_token(&)
        current = oauth2_authenticator_in_use
        current.nil? ? yield : current.__send__(:retrying_rejected_token, URI(base_url), &)
      end
    end
  end
end
