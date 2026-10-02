# frozen_string_literal: true

require "monitor"
require_relative "app_only_authenticator"
require_relative "errors/unsupported_operation"

module X
  module Core
    # The app-only copy of a client, for the endpoints that refuse OAuth 1.0a, included into ClientInternals
    # @api private
    module ClientAppOnly
      # The message of the error raised for a client that holds no credentials of the app to authenticate with
      NO_APP_CREDENTIALS = "A client that authenticates with OAuth 2.0 as a user, and holds neither the app's bearer " \
        "token nor its API key and secret, cannot authenticate as the app. Pass the client one of them, beside the " \
        "OAuth 2.0 credentials rather than an OAuth2Authenticator, which is given alone"
      private_constant :NO_APP_CREDENTIALS

      # A client that authenticates as the app, which Client#app_only returns
      #
      # A client that authenticates as a user returns a copy that authenticates with the app's bearer token, built
      # once; any other returns itself; see {Client#app_only}.
      #
      # @api private
      # @param client [Client] the client these are the internals of
      # @return [Client] a copy that authenticates with the bearer token, or the client itself
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user and holds no credentials of
      #   the app
      def app_only(client)
        case authenticator
        when OAuth1Authenticator, OAuth2Authenticator
          raise UnsupportedOperation, NO_APP_CREDENTIALS unless bearer_token || app_credentials

          app_only_copy(client)
        else client
        end
      end

      private

      # The app-only copy of the client, built once
      #
      # The credentials and settings of a client never change, so the copy is built once and returned from then on.
      # It is built under a lock, so that threads which ask for it together build one copy and fetch one token.
      #
      # @api private
      # @param client [Client] the client these are the internals of
      # @return [Client] the copy
      def app_only_copy(client)
        @app_only_monitor.synchronize { @app_only ||= build_app_only(client) }
      end

      # Build a copy that holds the app's credentials and bearer token
      # @api private
      # @param client [Client] the client these are the internals of
      # @return [Client] the copy
      def build_app_only(client)
        key, secret = app_credentials
        with(client, {**credentials.to_h { |name, _| [name, nil] }, api_key: key, api_key_secret: secret, bearer_token: app_bearer_token})
      end

      # The app-only bearer token, the client's own or one it fetches
      # @api private
      # @return [String] the bearer token
      def app_bearer_token = bearer_token || app_token.__send__(:bearer_token)

      # The authenticator that fetches the app-only bearer token, shared with copies
      #
      # It is built once, and fetches the token when it is first asked for it, and holds it from then on, so the client,
      # and each copy of it that {#share_app_token} gave it to, fetch it once between them.
      #
      # @api private
      # @return [AppOnlyAuthenticator] the authenticator
      def app_token
        @app_only_monitor.synchronize do
          @app_token ||= begin
            key, secret = app_credentials #: [String, String]
            AppOnlyAuthenticator.new(api_key: key, api_key_secret: secret).__send__(:token_requests_over, @connection, base_url, headers)
          end
        end
      end

      # Share the app-only bearer token of the client this one was copied from
      #
      # A copy that holds the same credentials of the app, and the same base URL, would fetch the same token, from an
      # endpoint X limits the rate of, so it takes the authenticator that fetches the token of the client it was
      # copied from, rather than fetch one of its own for each copy, as a copy made for each request would. The
      # internals of the client copied call it on those of the copy with __send__, since it is private.
      #
      # @api private
      # @param other [ClientInternals] the internals of the client this one was copied from
      # @return [void]
      def share_app_token(other)
        credentials = app_credentials or return
        @app_token = other.__send__(:app_token) if credentials.eql?(other.__send__(:app_credentials)) && base_url.eql?(other.base_url)
      end

      # The API key and secret of the app
      #
      # They are the ones an OAuth1Authenticator signs with, which a client given one holds no copy of, or else the
      # client's own, of which it holds both or neither, since a credential outside a complete set is refused.
      #
      # @api private
      # @return [Array(String, String), nil] the API key and secret, or nil for a client that holds neither
      def app_credentials
        current = authenticator
        return [current.api_key, current.__send__(:api_key_secret)] if current.is_a?(OAuth1Authenticator)

        key = api_key
        secret = api_key_secret #: String
        [key, secret] if key
      end
    end
    private_constant :ClientAppOnly
  end
end
