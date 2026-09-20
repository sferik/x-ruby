# frozen_string_literal: true

require "net/http"
require "simple_oauth"
require "uri"

module X
  module Core
    # Sends the token requests that simple_oauth builds over a client's connection
    #
    # Internal to x-core: the app-only and OAuth 2.0 authenticators, and OAuth2Authorization, fetch tokens with it,
    # so that the proxy, timeouts, and debug output of a client apply to token requests too.
    #
    # @api private
    module TokenEndpoint
      extend self

      # Send a token request and read the token the endpoint returns
      #
      # @api private
      # @param token_request [SimpleOAuth::OAuth2::Request] the token request
      # @param connection [Connection] the connection to send it over
      # @return [SimpleOAuth::OAuth2::Token] the token
      # @raise [SimpleOAuth::OAuth2::Error] if the endpoint refuses the request, or returns no token
      # @example Refresh a token
      #   X::Core::TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token:), connection:)
      def fetch(token_request, connection:)
        response = connection.perform(request: post(token_request))
        SimpleOAuth::OAuth2::Token.from_response(status: response.code, body: response.body)
      end

      private

      # Build the POST that sends a token request
      # @api private
      # @param token_request [SimpleOAuth::OAuth2::Request] the token request
      # @return [Net::HTTP::Post] the request
      def post(token_request)
        request = Net::HTTP::Post.new(URI(token_request.url))
        token_request.headers.each { |name, value| request[name] = value }
        request.body = token_request.body
        request
      end
    end
  end
end
