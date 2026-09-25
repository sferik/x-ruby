# frozen_string_literal: true

require "net/http"
require "simple_oauth"
require "uri"
require_relative "response_parser"

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

      # The responses that say the endpoint failed to answer a request, rather than refused it
      FAILURES = [Net::HTTPTooManyRequests, Net::HTTPServerError].freeze

      # Send a token request and read the token the endpoint returns
      #
      # A response of 429 Too Many Requests, or of a server error, says that the endpoint failed to answer rather than
      # that it refused the credentials, so it raises the HTTPError a response of the API with that status raises,
      # which a client waits out or retries as it does that response, rather than an error that simple_oauth reports:
      # an AuthorizationError tells a caller to ask the user to authorize the app again, which an outage of the
      # endpoint is no reason to.
      #
      # @api private
      # @param token_request [SimpleOAuth::OAuth2::Request] the token request
      # @param connection [Connection] the connection to send it over
      # @return [SimpleOAuth::OAuth2::Token] the token
      # @raise [TooManyRequests] if the endpoint limits the rate of the request
      # @raise [ServerError] if the endpoint fails to answer
      # @raise [SimpleOAuth::OAuth2::Error] if the endpoint refuses the request, or returns no token
      # @example Refresh a token
      #   X::Core::TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token:), connection:)
      def fetch(token_request, connection:)
        request = post(token_request)
        response = connection.perform(request:)
        raise ResponseParser.new.error(response, request) if failure?(response)

        SimpleOAuth::OAuth2::Token.from_response(status: response.code, body: response.body)
      end

      private

      # Check whether the endpoint failed to answer, rather than refused the request
      # @api private
      # @param response [Net::HTTPResponse] the response of the endpoint
      # @return [Boolean] true for 429 Too Many Requests or a server error
      def failure?(response)
        FAILURES.any? { |failure| response.is_a?(failure) }
      end

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
