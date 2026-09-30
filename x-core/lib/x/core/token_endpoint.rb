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

      # The URL of a token endpoint at the origin of a base URL
      #
      # A token endpoint of X is requested at the scheme, host, and port of the base URL of the client that sends its
      # requests, so that a client pointed at another host, such as a test server or a recording proxy, sends its
      # credentials there, as it sends its requests, rather than to X. The path is the one X serves the endpoint at.
      #
      # @api private
      # @param base_url [String] the base URL of the client
      # @param token_url [String] the URL X serves the endpoint at
      # @return [String] the URL of the endpoint at the origin of the base URL
      # @example The token endpoint of a client pointed at a test server
      #   X::Core::TokenEndpoint.url_at("http://localhost:3000/2/", X::AppOnlyAuthenticator::TOKEN_URL)
      #   # => "http://localhost:3000/oauth2/token"
      def url_at(base_url, token_url)
        path = URI(token_url).path #: String
        String(URI.join(base_url, path))
      end

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
