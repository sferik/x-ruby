# frozen_string_literal: true

require "json"
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

      # The responses that refuse a token request whatever their body, as RFC 6749 refuses one
      REFUSALS = [Net::HTTPBadRequest, Net::HTTPUnauthorized].freeze
      private_constant :REFUSALS

      # The classes of the responses that answer a token request, with a token or a refusal, when their body is JSON
      ANSWERS = [Net::HTTPSuccess, Net::HTTPClientError].freeze
      private_constant :ANSWERS

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
      # The endpoint answers a token request as OAuth 2.0 does: with the token in a successful response of JSON, or
      # with a refusal of the request, which simple_oauth reports, in a response of 400 Bad Request or 401
      # Unauthorized, or of another status of 4xx whose body is JSON, as X refuses the API key and secret of an app
      # with a 403 Forbidden. Any other response says that the endpoint failed to answer rather than that it refused the credentials, as a
      # redirect does, or the page of a proxy, firewall, or captive portal, and so does a response of 429 Too Many
      # Requests, or of a server error. It raises the error a response of the API with that status raises: the
      # HTTPError of a status that is not successful, which a client waits out or retries as it does that response,
      # and InvalidResponse for a successful one whose body is not JSON, rather than an error that simple_oauth
      # reports: an AuthorizationError tells a caller to ask the user to authorize the app again, which a failure of
      # the network is no reason to.
      #
      # @api private
      # @param token_request [SimpleOAuth::OAuth2::Request] the token request
      # @param connection [Connection] the connection to send it over
      # @return [SimpleOAuth::OAuth2::Token] the token
      # @raise [TooManyRequests] if the endpoint limits the rate of the request
      # @raise [HTTPError] if the endpoint fails to answer, as a server error, a redirect, or a refusal whose body is
      #   not JSON says
      # @raise [InvalidResponse] if the endpoint answers successfully with a body that is not JSON
      # @raise [SimpleOAuth::OAuth2::Error] if the endpoint refuses the request, or returns no token
      # @example Refresh a token
      #   X::Core::TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token:), connection:)
      def fetch(token_request, connection:)
        request = post(token_request)
        response = connection.perform(request:)
        raise failure(response, request) unless answer?(response)

        SimpleOAuth::OAuth2::Token.from_response(status: response.code, body: response.body)
      end

      private

      # Check whether the endpoint answered as OAuth 2.0 does, with a token or a refusal
      #
      # A refusal is a response of a status REFUSALS names, whatever its body, or of another status of 4xx, other than
      # 429 Too Many Requests, whose body is JSON.
      #
      # @api private
      # @param response [Net::HTTPResponse] the response of the endpoint
      # @return [Boolean] true for a successful response of JSON, or a refusal
      def answer?(response)
        return true if REFUSALS.include?(response.class)

        ANSWERS.any? { |answer| response.is_a?(answer) } && !response.instance_of?(Net::HTTPTooManyRequests) &&
          json_object?(response.body)
      end

      # Check whether a body is a JSON object
      # @api private
      # @param body [String] the body of the response
      # @return [Boolean] true if the body parses to a Hash
      def json_object?(body)
        JSON.parse(body).instance_of?(Hash)
      rescue JSON::ParserError
        false
      end

      # Create the error of a response in which the endpoint failed to answer
      # @api private
      # @param response [Net::HTTPResponse] the response of the endpoint
      # @param request [Net::HTTP::Post] the token request, which the error names
      # @return [HTTPError, InvalidResponse] the error of the status of the response, or InvalidResponse for a
      #   successful one
      def failure(response, request)
        return ResponseParser.new.error(response, request) unless response.is_a?(Net::HTTPSuccess)

        InvalidResponse.new(http_response: response, body: response.body, request:)
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
