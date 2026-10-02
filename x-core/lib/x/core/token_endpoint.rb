# frozen_string_literal: true

require "json"
require "net/http"
require "simple_oauth"
require "uri"
require_relative "credential_validator"
require_relative "errors/authorization_error"
require_relative "errors/invalid_response"
require_relative "authenticator"
require_relative "request_builder"
require_relative "request_context"
require_relative "response_parser"

module X
  module Core
    # Sends the token requests that simple_oauth builds over a client's connection
    #
    # Internal to x-core: the app-only and OAuth 2.0 authenticators, and OAuth2Authorization, fetch tokens with it,
    # so that the proxy, timeouts, debug output, and headers of a client apply to token requests too.
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

      # The version of the API that ends the path of a base URL, such as the /2/ of https://api.x.com/2/
      API_VERSION = %r{/\d+(?:\.\d+)*/?\z}
      private_constant :API_VERSION

      # The URL of a token endpoint at a base URL, under the path it serves the API at
      #
      # A token endpoint of X is requested at the scheme, host, and port of the base URL of the client that sends its
      # requests, so that a client pointed at another host, such as a test server or a recording proxy, sends its
      # credentials there, as it sends its requests, rather than to X. The path is the one X serves the endpoint at,
      # under the path the base URL serves the API at, which is its path without the version of the API that ends it,
      # so that a gateway that serves the API under a path of its own, as https://gateway.example/x/2/ serves it under
      # /x, serves the token endpoints under that path too, as X serves them beside the API.
      #
      # @api private
      # @param base_url [String] the base URL of the client
      # @param token_url [String] the URL X serves the endpoint at
      # @return [String] the URL of the endpoint at the origin of the base URL
      # @example The token endpoint of a client pointed at a test server
      #   X::Core::TokenEndpoint.url_at("http://localhost:3000/2/", X::AppOnlyAuthenticator::TOKEN_URL)
      #   # => "http://localhost:3000/oauth2/token"
      # @example The token endpoint of a client pointed at a gateway that serves the API under a path
      #   X::Core::TokenEndpoint.url_at("https://gateway.example/x/2/", X::OAuth2Authenticator::TOKEN_URL)
      #   # => "https://gateway.example/x/2/oauth2/token"
      def url_at(base_url, token_url)
        base_path, path = URI(base_url).path, URI(token_url).path #: [String, String]
        mount = base_path.sub(API_VERSION, "").chomp("/")
        String(URI.join(base_url, "#{mount}#{path}"))
      end

      # The scopes a token names
      #
      # A token response names the scopes it granted as one String, each scope apart from the next by a space.
      #
      # @api private
      # @param token [SimpleOAuth::OAuth2::Token] the token the endpoint returned
      # @return [Array<String>, nil] the scopes, frozen, or nil if the token names none
      # @example Read the scopes of a token
      #   X::Core::TokenEndpoint.scopes_of(token) # => ["tweet.read", "users.read", "offline.access"]
      def scopes_of(token)
        scopes = String.try_convert(token.scope).to_s.split
        CredentialValidator.frozen_scopes(scopes) unless scopes.empty?
      end

      # Send a token request and read the token the endpoint returns
      #
      # The endpoint answers a token request as OAuth 2.0 does: with the token in a successful response of JSON, or
      # with a refusal of the request, which raises AuthorizationError, in a response of 400 Bad Request or 401
      # Unauthorized, or of another status of 4xx whose body is JSON, as X refuses the API key and secret of an app
      # with a 403 Forbidden. Any other response says that the endpoint failed to answer rather than that it refused the credentials, as a
      # redirect does, or the page of a proxy, firewall, or captive portal, and so does a response of 429 Too Many
      # Requests, or of a server error. It raises the error a response of the API with that status raises: the
      # HTTPError of a status that is not successful, which a client waits out or retries as it does that response,
      # and InvalidResponse for a successful one whose body is not JSON, or holds no token, rather than
      # AuthorizationError, which tells a caller to ask the user to authorize the app again, which a failure of the
      # network is no reason to.
      #
      # @api private
      # @param token_request [SimpleOAuth::OAuth2::Request] the token request
      # @param connection [Connection] the connection to send it over
      # @param refusal [String] the message of a refusal that describes no reason
      # @param headers [Hash{String => String}] the headers of the client that sends it; see {#post}
      # @return [SimpleOAuth::OAuth2::Token] the token
      # @raise [TooManyRequests] if the endpoint limits the rate of the request
      # @raise [HTTPError] if the endpoint fails to answer, as a server error, a redirect, or a refusal whose body is
      #   not JSON says
      # @raise [InvalidResponse] if the endpoint answers successfully with a body that is not JSON, or holds no token
      # @raise [AuthorizationError] if the endpoint refuses the request, with the response that refused it
      # @example Refresh a token
      #   X::Core::TokenEndpoint.fetch(oauth2_client.refresh_token_request(refresh_token:), connection:,
      #     refusal: "Token refresh failed", headers: client.headers)
      def fetch(token_request, connection:, refusal:, headers:)
        request = post(token_request, headers)
        response = connection.perform(request:)
        raise failure(response, request) unless answer?(response)

        token_of(response, request, refusal)
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

      # The token a response of the endpoint holds
      #
      # The error raised in place of it is raised with the cause of the failure simple_oauth reports, rather than the
      # failure, so that its cause is the error of x-core it was raised in rescue of, such as the Unauthorized that led
      # a client to refresh, and nil for none.
      #
      # @api private
      # @param response [Net::HTTPResponse] the response of the endpoint, a token or a refusal
      # @param request [Net::HTTP::Post] the token request, which the error names
      # @param refusal [String] the message of a refusal that describes no reason
      # @return [SimpleOAuth::OAuth2::Token] the token
      # @raise [AuthorizationError] if the response refuses the request
      # @raise [InvalidResponse] if the response is successful, but holds no token
      def token_of(response, request, refusal)
        SimpleOAuth::OAuth2::Token.from_response(status: response.code, body: response.body)
      rescue SimpleOAuth::OAuth2::Error => e
        raise refused(e, response, request, refusal), cause: e.cause
      end

      # Create the error of a response that holds no token
      #
      # Its message is the reason X described, or else the error code it reported, or else the message given.
      #
      # @api private
      # @param error [SimpleOAuth::OAuth2::Error] the failure simple_oauth reports of the response
      # @param response [Net::HTTPResponse] the response of the endpoint
      # @param request [Net::HTTP::Post] the token request, which the error names
      # @param refusal [String] the message of a refusal that describes no reason
      # @return [AuthorizationError, InvalidResponse] the error of a refusal, or InvalidResponse for a successful
      #   response that holds no token
      def refused(error, response, request, refusal)
        message = error.description || error.code || refusal
        return InvalidResponse.new(message, http_response: response, **RequestContext.of(request)) if response.is_a?(Net::HTTPSuccess)

        AuthorizationError.new(message, http_response: response, **RequestContext.of(request))
      end

      # Create the error of a response in which the endpoint failed to answer
      # @api private
      # @param response [Net::HTTPResponse] the response of the endpoint
      # @param request [Net::HTTP::Post] the token request, which the error names
      # @return [HTTPError, InvalidResponse] the error of the status of the response, or InvalidResponse for a
      #   successful one
      def failure(response, request)
        return ResponseParser.new.error(response, request) unless response.is_a?(Net::HTTPSuccess)

        InvalidResponse.new(http_response: response, **RequestContext.of(request))
      end

      # Build the POST that sends a token request
      #
      # It is sent with the headers a request of the API is sent with: the User-Agent of the gem, and the headers of
      # the client, which replace it, so that a gateway the base URL names, which may require a header of its own, is
      # sent it with the token requests of the client too. The headers of the token request itself replace both, as
      # its credentials and its form content type, and the client's Authorization header is never sent, since a token
      # request carries its own credentials, or none, as the refresh of a public client does.
      #
      # @api private
      # @param token_request [SimpleOAuth::OAuth2::Request] the token request
      # @param headers [Hash{String => String}] the headers of the client that sends it
      # @return [Net::HTTP::Post] the request
      def post(token_request, headers)
        request = Net::HTTP::Post.new(URI(token_request.url))
        client_headers = headers.reject { |name, _| name.casecmp?(Authenticator::AUTHENTICATION_HEADER) }
        [RequestBuilder::DEFAULT_HEADERS, client_headers, token_request.headers].each do |sent|
          sent.each { |name, value| request[name] = value }
        end
        request.body = token_request.body
        request
      end
    end
    private_constant :TokenEndpoint
  end
end
