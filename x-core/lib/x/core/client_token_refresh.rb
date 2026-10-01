# frozen_string_literal: true

require_relative "app_only_authenticator"
require_relative "oauth2_authenticator"
require_relative "setting_validator"

module X
  module Core
    # The OAuth 2.0 authenticator of a client, which its copies share, and the tokens it last refreshed, included into
    # ClientInternals
    # @api private
    module ClientTokenRefresh
      # The message of the error raised for a copy given an expiration time or scopes for the access token it shares
      SHARED_EXPIRATION = "A copy that shares the access token of the client shares its expiration time and scopes, " \
        "so it cannot be given %s. Pass it beside the access token and refresh token it belongs to"
      private_constant :SHARED_EXPIRATION
      # The options that belong to the tokens of the client, which a copy that leaves its OAuth 2.0 authenticator
      # holds only when it is given them
      TOKEN_OPTIONS = %i[refresh_token expires_at scopes save_tokens load_tokens].freeze
      private_constant :TOKEN_OPTIONS

      # The time the OAuth 2.0 access token expires, as last refreshed
      #
      # {Client#expires_at} returns it.
      #
      # @api private
      # @return [Time, nil] the expiration time, or nil if it is not known
      def expires_at
        current = oauth2_authenticator_in_use
        current ? current.expires_at : @expires_at
      end

      # The scopes X granted the OAuth 2.0 access token, as last refreshed
      #
      # {Client#scopes} returns it.
      #
      # @api private
      # @return [Array<String>, nil] the scopes, or nil if they are not known
      def scopes
        current = oauth2_authenticator_in_use
        current ? current.scopes : @scopes
      end

      private

      # Initialize the callables that store and load the tokens of a refresh
      # @api private
      # @param save_tokens [#call, nil] the callable passed the OAuth2Tokens of each refresh
      # @param load_tokens [#call, nil] the callable that returns the OAuth2Tokens in the store
      # @return [void]
      # @raise [ArgumentError] if save_tokens or load_tokens is neither nil nor responds to call
      def initialize_token_hooks(save_tokens:, load_tokens:)
        @save_tokens = SettingValidator.callable!(:save_tokens, save_tokens)
        @load_tokens = SettingValidator.callable!(:load_tokens, load_tokens)
      end

      # Share the authenticator of the client this one was copied from
      #
      # A copy that holds the credentials of the client shares its OAuth 2.0 or app-only authenticator, so that the
      # copy refreshes the tokens of the client, or sends the bearer token it fetched, rather than hold tokens of its
      # own. A copy given an authenticator of its own keeps it. The internals of the client copied call it on those of
      # the copy with __send__, since it is private.
      #
      # @api private
      # @param copy [Client] the copy these are the internals of
      # @param other [Authenticator] the authenticator of the client this one was copied from
      # @param options [Hash] the options the copy was given in place of the client's
      # @return [void]
      def share_authenticator(copy, other, options)
        return if options[:authenticator]

        case other
        when AppOnlyAuthenticator then share_app_only(other, options)
        when OAuth2Authenticator then share_oauth2(copy, other, options)
        end
      end

      # Share the OAuth 2.0 authenticator of the client this one was copied from
      #
      # A refresh by either client then reaches both. X accepts a refresh token once, so a copy that refreshed with
      # an authenticator of its own would leave the original client with a refresh token that no longer works.
      #
      # Whether the two share it is decided by the options the copy was given, not by the tokens it was built with:
      # a refresh on another thread may replace them while it is built, and a copy that held on to the ones replaced
      # could never refresh again. The expiration time and scopes are facts about the access token the two hold, so a
      # copy that shares it is refused either, rather than set it for the client it was copied from.
      #
      # @api private
      # @param copy [Client] the copy these are the internals of
      # @param other [OAuth2Authenticator] the authenticator of the client this one was copied from
      # @param options [Hash] the options the copy was given in place of the client's
      # @return [void]
      # @raise [ArgumentError] if the copy shares the authenticator and was given an expiration time or scopes
      def share_oauth2(copy, other, options)
        return unless oauth2_authenticator_in_use && other.__send__(:holds?, options)

        given = options.keys & %i[expires_at scopes]
        raise ArgumentError, format(SHARED_EXPIRATION, given.join(" or ")) unless given.empty?

        @authenticator = join(copy, other)
      end

      # The options of a copy, without the client's tokens unless it shares them
      #
      # A copy given a client ID, client secret, access token, or refresh token the authenticator does not hold, or
      # an authenticator of its own, does not share it, and authenticates with tokens that may be another user's. It
      # holds the refresh token, expiration time, scopes, save_tokens, and load_tokens of the client only when it is
      # given them: a refresh of the copy would otherwise spend the refresh token the client holds, which X accepts
      # once, read the store of the client with its load_tokens and take the client's tokens in place of its own, or
      # pass its tokens to the save_tokens of the client, which would store them in place of the client's.
      #
      # @api private
      # @param copied [Hash{Symbol => Object}] the options the copy is built with
      # @param options [Hash{Symbol => Object}] the options the copy was given
      # @return [Hash{Symbol => Object}] the options, without those of the tokens of the client the copy was not given
      def without_tokens_of_client(copied, options)
        current = oauth2_authenticator_in_use or return copied
        return copied unless options[:authenticator] || !current.__send__(:holds?, options)

        copied.except(*(TOKEN_OPTIONS - options.keys))
      end

      # Share the app-only authenticator of the client this one was copied from
      #
      # It is shared by a copy that authenticates as the app with the API key and secret the authenticator holds,
      # and was given no bearer token of its own, so the bearer token the client fetched, or fetches, is fetched once.
      #
      # @api private
      # @param other [AppOnlyAuthenticator] the authenticator of the client this one was copied from
      # @param options [Hash] the options the copy was given in place of the client's
      # @return [void]
      def share_app_only(other, options)
        @authenticator = other if AppOnlyAuthenticator === @authenticator && other.__send__(:holds?, options)
      end

      # Take an authenticator the client was given, as it would one it built
      #
      # The token requests of an authenticator that makes them are sent over the connection of the first client
      # given it, and the refreshes of an OAuth 2.0 one reach the save_tokens of each client that shares it.
      #
      # @api private
      # @param client [Client] the client these are the internals of
      # @param authenticator [Authenticator] the authenticator
      # @return [Authenticator] the authenticator
      def take(client, authenticator)
        case authenticator
        when OAuth2Authenticator then join(client, authenticator.__send__(:token_requests_over, @connection, base_url))
        when AppOnlyAuthenticator then authenticator.__send__(:token_requests_over, @connection, base_url)
        else authenticator
        end
      end

      # Join the clients whose save_tokens an OAuth 2.0 authenticator reports to
      # @api private
      # @param client [Client] the client these are the internals of
      # @param authenticator [OAuth2Authenticator] the authenticator
      # @return [OAuth2Authenticator] the authenticator
      def join(client, authenticator)
        clients = authenticator.__send__(:clients)
        clients[client] = true
        authenticator.__send__(:report_refreshes_to, -> { clients.keys.filter_map(&:save_tokens).uniq })
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
      # builds, when the two hold the same credentials; see share_authenticator. A client ID and access token without
      # a refresh token, as an authorization without offline.access issues them, build an authenticator that acts
      # for the user and cannot refresh.
      #
      # @api private
      # @param client [Client] the client these are the internals of
      # @return [OAuth2Authenticator, nil] the OAuth 2.0 authenticator or nil
      def oauth2_authenticator(client)
        client_id = @client_id
        access_token = @access_token
        return unless client_id && access_token

        new_oauth2_authenticator(client, client_id:, access_token:, refresh_token: @refresh_token)
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
      # hook given to save_tokens is passed the OAuth2Tokens of the refresh it reports.
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
      # @param client [Client] the client these are the internals of
      # @param client_id [String] the OAuth 2.0 client ID
      # @param access_token [String] the OAuth 2.0 access token
      # @param refresh_token [String, nil] the OAuth 2.0 refresh token, or nil for an access token that is not refreshed
      # @return [OAuth2Authenticator] the OAuth 2.0 authenticator
      def new_oauth2_authenticator(client, client_id:, access_token:, refresh_token:)
        authenticator = OAuth2Authenticator.new(client_id:, client_secret: @client_secret, access_token:, refresh_token:, expires_at: @expires_at, scopes: @scopes)
        join(client, authenticator.__send__(:token_requests_over, @connection, base_url))
      end

      # Run a request, again if a refresh replaces an OAuth 2.0 token the API rejects
      #
      # Only a rejection by the origin of the base URL, which the token is sent to, refreshes it; see {Origin}. An
      # app-only bearer token the API rejects is fetched again the same way; see {AppOnlyAuthenticator}. A streaming
      # client runs each stream through it, and calls it with __send__, since it is private.
      #
      # @api private
      # @param client [Client, nil] the client these are the internals of, which a refresh that fails to report is
      #   raised with, or nil for a stream, which authenticates as the app and so refreshes no OAuth 2.0 token
      # @yield runs the request
      # @return [Object] what the block returns
      def refreshing_rejected_token(client = nil, &)
        case (current = @authenticator)
        when OAuth2Authenticator then current.__send__(:retrying_rejected_token, URI(base_url), @connection, client, &)
        when AppOnlyAuthenticator then current.__send__(:retrying_rejected_token, URI(base_url), &)
        else yield
        end
      end
    end
    private_constant :ClientTokenRefresh
  end
end
