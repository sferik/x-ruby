require_relative "oauth2_authenticator"

module X
  module Core
    # The OAuth 2.0 authenticator of a client, which its copies share, and the tokens it last refreshed, included into
    # Client
    # @api private
    module ClientTokenRefresh
      # The access token for OAuth authentication, as last refreshed
      #
      # @api public
      # @return [String, nil] the access token for OAuth authentication
      # @example Get the access token
      #   client.access_token
      def access_token
        current = oauth2_authenticator_in_use
        current ? current.access_token : @access_token
      end

      # The OAuth 2.0 refresh token, as last refreshed
      #
      # @api public
      # @return [String, nil] the OAuth 2.0 refresh token
      # @example Get the refresh token
      #   client.refresh_token
      def refresh_token
        current = oauth2_authenticator_in_use
        current ? current.refresh_token : @refresh_token
      end

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
        return unless current && other.is_a?(OAuth2Authenticator) && oauth2_credentials_of(current).eql?(oauth2_credentials_of(other))

        other.update_expires_at(expires_at)
        @authenticator = other
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
      # A client keeps the authenticator it has while its client ID and secret and its tokens are the ones the
      # authenticator holds, so that changing another credential or setting leaves it sharing the authenticator with
      # its copies. A new expiration time is set on that authenticator, for every client that shares it, since an
      # authenticator of its own would hold a refresh token that X accepts once from either.
      #
      # @api private
      # @return [OAuth2Authenticator, nil] the OAuth 2.0 authenticator or nil
      def oauth2_authenticator
        client_id = @client_id
        access_token = @access_token
        refresh_token = @refresh_token
        return unless client_id && access_token && refresh_token

        current = oauth2_authenticator_in_use
        held = [client_id, @client_secret, access_token, refresh_token]
        return new_oauth2_authenticator(client_id:, access_token:, refresh_token:) unless current && oauth2_credentials_of(current).eql?(held)

        current.tap { |authenticator| authenticator.update_expires_at(@expires_at) }
      end

      private

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
          connection: @connection, on_refresh: ->(authenticator) { clients.keys.filter_map(&:on_token_refresh).uniq.each { |hook| hook.call(authenticator) } })
      end

      # The credentials that tell one OAuth 2.0 authenticator from another
      #
      # The expiration time is left out: it says when the access token expires, and two authenticators that hold the
      # same tokens hold the same refresh token, which X accepts once.
      #
      # @api private
      # @param authenticator [OAuth2Authenticator] the authenticator
      # @return [Array<String, nil>] the client ID and secret, and the tokens
      def oauth2_credentials_of(authenticator)
        [authenticator.client_id, authenticator.client_secret, authenticator.access_token, authenticator.refresh_token]
      end

      # Run a request, again if a refresh replaces an OAuth 2.0 token the API rejects
      # @api private
      # @yield runs the request
      # @return [Object] what the block returns
      def refreshing_rejected_token(&)
        current = oauth2_authenticator_in_use
        current.nil? ? yield : current.retrying_rejected_token(&)
      end
    end
  end
end
