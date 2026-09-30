# frozen_string_literal: true

require "monitor"
require_relative "app_only_authenticator"
require_relative "errors/unsupported_operation"

module X
  module Core
    # The app-only copy of a client, for the endpoints that refuse OAuth 1.0a, included into Client
    # @api private
    module ClientAppOnly
      # The message of the error raised for a client that holds no credentials of the app to authenticate with
      NO_APP_CREDENTIALS = "A client that authenticates with OAuth 2.0 as a user, and holds neither the app's bearer " \
        "token nor its API key and secret, cannot authenticate as the app. Pass the client one of them, beside the " \
        "OAuth 2.0 credentials rather than an OAuth2Authenticator, which is given alone"
      private_constant :NO_APP_CREDENTIALS

      # A client that authenticates as the app, for the endpoints that refuse OAuth 1.0a
      #
      # A client that authenticates as a user, signing with OAuth 1.0a or with OAuth 2.0, returns a copy that
      # authenticates with the app's bearer token: the one it was given, or one it fetches with its API key and secret
      # the first time. It returns the same copy, with the connections it keeps open, from then on, since the
      # credentials and settings of a client never change; threads that ask for the copy together get one. A client
      # with a bearer token or an API key and secret alone already authenticates as the app, and is returned as it is,
      # as is one given an authenticator that authenticates as the app, or as no one. A client given an
      # OAuth1Authenticator fetches the token with the API key and secret it signs with. A client that authenticates
      # with OAuth 2.0 as a user and holds neither the app's bearer token nor its API key and secret, as a client
      # given an OAuth2Authenticator holds neither, raises, rather than send the user's credentials to an endpoint
      # that would refuse them with 403 Forbidden.
      #
      # @api public
      # @return [Client] a copy that authenticates with the bearer token, or the client itself
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user and holds no credentials of
      #   the app
      # @example Add a filtered stream rule, which takes app-only authentication
      #   client.app_only.post("tweets/search/stream/rules", {add: [{value: "ruby"}]})
      def app_only
        case authenticator
        when OAuth1Authenticator, OAuth2Authenticator
          raise UnsupportedOperation, NO_APP_CREDENTIALS unless bearer_token || app_credentials

          app_only_copy
        else self
        end
      end

      private

      # The app-only copy of the client, built once
      #
      # The credentials and settings of a client never change, so the copy is built once and returned from then on.
      # It is built under a lock, so that threads which ask for it together build one copy and fetch one token.
      #
      # @api private
      # @return [Client] the copy
      def app_only_copy
        @app_only_monitor.synchronize { @app_only ||= build_app_only }
      end

      # Build a copy that holds the app's credentials and bearer token
      # @api private
      # @return [Client] the copy
      def build_app_only
        key, secret = app_credentials
        with(**credentials.to_h { |name, _| [name, nil] }, api_key: key, api_key_secret: secret, bearer_token: app_bearer_token)
      end

      # The app-only bearer token, the client's own or one it fetches
      # @api private
      # @return [String] the bearer token
      def app_bearer_token
        key, secret = app_credentials #: [String, String]
        bearer_token || AppOnlyAuthenticator.new(api_key: key, api_key_secret: secret).__send__(:token_requests_over, @connection, base_url).__send__(:bearer_token)
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
