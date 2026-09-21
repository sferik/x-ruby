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
      NO_APP_CREDENTIALS = "A client that authenticates with OAuth 2.0 as a user holds no credentials of the app, so " \
        "it cannot authenticate as the app. Build a client from the app's bearer token, or its API key and secret, instead"
      private_constant :NO_APP_CREDENTIALS

      # A client that authenticates as the app, for the endpoints that refuse OAuth 1.0a
      #
      # A client that signs with OAuth 1.0a fetches an app-only bearer token with its API key and secret the first
      # time, and returns the same copy, with the connections it keeps open, until its credentials or settings change,
      # when it closes the connections of that copy and builds another; threads that ask for the copy together get one.
      # A client with a bearer token or an API key and secret already authenticates as the app, and is returned as it
      # is. A client that authenticates with OAuth 2.0 as a user holds no credentials of the app, so it raises rather
      # than send the user's credentials to an endpoint that would refuse them with 403 Forbidden.
      #
      # @api public
      # @return [Client] a copy that authenticates with the bearer token, or the client itself
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user
      # @example Add a filtered stream rule, which takes app-only authentication
      #   client.app_only.post("tweets/search/stream/rules", {add: [{value: "ruby"}]})
      def app_only
        case authenticator
        when OAuth1Authenticator then app_only_copy
        when OAuth2Authenticator then raise UnsupportedOperation, NO_APP_CREDENTIALS
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
        with(**credentials.to_h { |name, _| [name, nil] }, api_key:, api_key_secret:, bearer_token: app_bearer_token)
      end

      # The app-only bearer token, the client's own or one it fetches
      # @api private
      # @return [String] the bearer token
      def app_bearer_token
        key = api_key #: String
        secret = api_key_secret #: String
        bearer_token || AppOnlyAuthenticator.new(api_key: key, api_key_secret: secret, connection: @connection).bearer_token
      end
    end
  end
end
