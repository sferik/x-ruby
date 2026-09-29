# frozen_string_literal: true

require_relative "app_only_authenticator"
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

      private

      # Share the OAuth 2.0 authenticator of the client this one was copied from
      #
      # A refresh by either client then reaches both. X accepts a refresh token once, so a copy that refreshed with
      # an authenticator of its own would leave the original client with a refresh token that no longer works.
      #
      # Whether the two share it is decided by the options the copy was given, not by the tokens it was built with:
      # a refresh on another thread may replace them while it is built, and a copy that held on to the ones replaced
      # could never refresh again. The expiration time is a fact about the access token the two hold, so a copy given
      # another sets it for both. A copy given an authenticator of its own keeps it.
      #
      # @api private
      # @param other [Authenticator] the authenticator of the client this one was copied from
      # @param options [Hash] the options the copy was given in place of the client's
      # @return [void]
      def share_authenticator(other, options)
        return if options[:authenticator]
        return unless oauth2_authenticator_in_use && other.is_a?(OAuth2Authenticator) && other.__send__(:holds?, options)

        other.__send__(:update_expires_at, options.fetch(:expires_at)) if options.key?(:expires_at)
        @authenticator = join(other)
      end

      # Take an authenticator the client was given, as it would one it built
      #
      # The token requests of an authenticator that makes them are sent over the connection of the first client
      # given it, and the refreshes of an OAuth 2.0 one reach the on_token_refresh of each client that shares it.
      #
      # @api private
      # @param authenticator [Authenticator] the authenticator
      # @return [Authenticator] the authenticator
      def take(authenticator)
        case authenticator
        when OAuth2Authenticator then join(authenticator.__send__(:token_requests_over, @connection))
        when AppOnlyAuthenticator then authenticator.__send__(:token_requests_over, @connection)
        else authenticator
        end
      end

      # Join the clients whose on_token_refresh an OAuth 2.0 authenticator reports to
      # @api private
      # @param authenticator [OAuth2Authenticator] the authenticator
      # @return [OAuth2Authenticator] the authenticator
      def join(authenticator)
        clients = authenticator.__send__(:clients)
        clients[self] = true
        authenticator.__send__(:report_refreshes_to, -> { clients.keys.filter_map(&:on_token_refresh).uniq })
        authenticator
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

      # The OAuth 2.0 authenticator of the client's credentials, as last refreshed
      #
      # It is the one the client built of them, or shares with the client it was copied from. A client given its
      # authenticator holds no credentials, so the tokens of that authenticator are none of its credentials, which a
      # copy would be built with beside it.
      #
      # @api private
      # @return [OAuth2Authenticator, nil] the authenticator, or nil for a client that holds no OAuth 2.0 credentials
      def oauth2_credentials_in_use = (oauth2_authenticator_in_use unless @given_authenticator)

      # The access token for OAuth authentication, as last refreshed
      #
      # It is private, as {ClientCredentials#api_key_secret} is, and as the access token of the authenticator is. A
      # hook given to on_token_refresh is passed the OAuth2Tokens of the refresh it reports.
      #
      # @api private
      # @return [String, nil] the access token for OAuth authentication
      def access_token
        current = oauth2_credentials_in_use
        current ? current.__send__(:access_token) : @access_token
      end

      # The OAuth 2.0 refresh token, as last refreshed
      #
      # It is private for the reason {#access_token} is.
      #
      # @api private
      # @return [String, nil] the OAuth 2.0 refresh token
      def refresh_token
        current = oauth2_credentials_in_use
        current ? current.__send__(:refresh_token) : @refresh_token
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
        authenticator = OAuth2Authenticator.new(client_id:, client_secret: @client_secret, access_token:, refresh_token:, expires_at: @expires_at)
        join(authenticator.__send__(:token_requests_over, @connection))
      end

      # Run a request, again if a refresh replaces an OAuth 2.0 token the API rejects
      #
      # Only a rejection by the origin of the base URL, which the token is sent to, refreshes it; see {Origin}. An
      # app-only bearer token the API rejects is fetched again the same way; see {AppOnlyAuthenticator}.
      #
      # @api private
      # @yield runs the request
      # @return [Object] what the block returns
      def refreshing_rejected_token(&)
        case (current = @authenticator)
        when OAuth2Authenticator then current.__send__(:retrying_rejected_token, URI(base_url), @connection, &)
        when AppOnlyAuthenticator then current.__send__(:retrying_rejected_token, URI(base_url), &)
        else yield
        end
      end
    end
  end
end
