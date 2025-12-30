require "base64"
require "json"
require "net/http"
require "uri"
require_relative "authenticator"
require_relative "connection"

module X
  # Handles OAuth 2.0 authentication with token refresh capability
  # @api public
  class OAuth2Authenticator < Authenticator
    # Path for the OAuth 2.0 token endpoint
    TOKEN_PATH = "/2/oauth2/token".freeze
    # Host for token refresh requests
    TOKEN_HOST = "api.twitter.com".freeze
    # Grant type for token refresh
    REFRESH_GRANT_TYPE = "refresh_token".freeze

    # The OAuth 2.0 client ID
    # @api public
    # @return [String] the client ID
    # @example Get the client ID
    #   authenticator.client_id
    attr_accessor :client_id
    # The OAuth 2.0 client secret
    # @api public
    # @return [String] the client secret
    # @example Get the client secret
    #   authenticator.client_secret
    attr_accessor :client_secret
    # The OAuth 2.0 access token
    # @api public
    # @return [String] the access token
    # @example Get the access token
    #   authenticator.access_token
    attr_accessor :access_token
    # The OAuth 2.0 refresh token
    # @api public
    # @return [String] the refresh token
    # @example Get the refresh token
    #   authenticator.refresh_token
    attr_accessor :refresh_token
    # The expiration time of the access token
    # @api public
    # @return [Time, nil] the expiration time
    # @example Get the expiration time
    #   authenticator.expires_at
    attr_accessor :expires_at

    # The connection for making token requests
    # @api public
    # @return [Connection] the connection instance
    # @example Get the connection
    #   authenticator.connection
    attr_accessor :connection

    # Initialize a new OAuth 2.0 authenticator
    #
    # @api public
    # @param client_id [String] the OAuth 2.0 client ID
    # @param client_secret [String] the OAuth 2.0 client secret
    # @param access_token [String] the OAuth 2.0 access token
    # @param refresh_token [String] the OAuth 2.0 refresh token
    # @param expires_at [Time, nil] the expiration time of the access token
    # @param connection [Connection] the connection for making token requests
    # @return [OAuth2Authenticator] a new authenticator instance
    # @example Create an authenticator
    #   authenticator = X::OAuth2Authenticator.new(
    #     client_id: "id",
    #     client_secret: "secret",
    #     access_token: "token",
    #     refresh_token: "refresh"
    #   )
    def initialize(client_id:, client_secret:, access_token:, refresh_token:, expires_at: nil,
      connection: Connection.new)
      @client_id = client_id
      @client_secret = client_secret
      @access_token = access_token
      @refresh_token = refresh_token
      @expires_at = expires_at
      @connection = connection
    end

    # Generate the authentication header
    #
    # @api public
    # @param _request [Net::HTTPRequest, nil] the HTTP request (unused)
    # @return [Hash{String => String}] the authentication header
    # @example Get the header
    #   authenticator.header(request)
    def header(_request)
      {AUTHENTICATION_HEADER => "Bearer #{access_token}"}
    end

    # Check if the access token has expired
    #
    # @api public
    # @return [Boolean] true if the token has expired
    # @example Check expiration
    #   authenticator.token_expired?
    def token_expired?
      return false if expires_at.nil?

      Time.now >= expires_at
    end

    # Refresh the access token using the refresh token
    #
    # @api public
    # @return [Hash{String => Object}] the token response
    # @raise [Error] if token refresh fails
    # @example Refresh the token
    #   authenticator.refresh_token!
    def refresh_token!
      response = send_token_request
      handle_token_response(response)
    end

    private

    # Send the token refresh request
    # @api private
    # @return [Net::HTTPResponse] the HTTP response
    def send_token_request
      request = build_token_request
      connection.perform(request: request)
    end

    # Build the token refresh request
    # @api private
    # @return [Net::HTTP::Post] the POST request
    def build_token_request
      uri = URI::HTTPS.build(host: TOKEN_HOST, path: TOKEN_PATH)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request["Authorization"] = "Basic #{Base64.strict_encode64("#{client_id}:#{client_secret}")}"
      request.body = URI.encode_www_form(grant_type: REFRESH_GRANT_TYPE, refresh_token: refresh_token)
      request
    end

    # Handle the token response
    # @api private
    # @param response [Net::HTTPResponse] the HTTP response
    # @return [Hash{String => Object}] the parsed response body
    # @raise [Error] if the response indicates an error
    def handle_token_response(response)
      body = JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, "Token refresh failed"
    else
      raise Error, body["error_description"] || body["error"] || "Token refresh failed" unless response.is_a?(Net::HTTPSuccess)

      update_tokens(body)
      body
    end

    # Update tokens from the response
    # @api private
    # @param token_response [Hash{String => Object}] the token response
    # @return [void]
    def update_tokens(token_response)
      @access_token = token_response.fetch("access_token")
      @refresh_token = token_response.fetch("refresh_token") if token_response.key?("refresh_token")
      @expires_at = Time.now + token_response.fetch("expires_in") if token_response.key?("expires_in")
    end
  end
end
