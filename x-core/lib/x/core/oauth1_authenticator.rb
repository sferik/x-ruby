require "simple_oauth"
require "uri"
require_relative "authenticator"

module X
  # Authenticator for OAuth 1.0a authentication
  # @api public
  class OAuth1Authenticator < Authenticator
    # OAuth version
    OAUTH_VERSION = SimpleOAuth::Header::OAUTH_VERSION
    # OAuth signature method
    OAUTH_SIGNATURE_METHOD = SimpleOAuth::Header::DEFAULT_SIGNATURE_METHOD
    # The media type whose body OAuth 1.0a signs as request parameters
    FORM_CONTENT_TYPE = "application/x-www-form-urlencoded".freeze

    # The API key (consumer key)
    # @api public
    # @return [String] the API key (consumer key)
    # @example Get or set the API key
    #   authenticator.api_key = "key"
    attr_accessor :api_key

    # The API key secret (consumer secret)
    # @api public
    # @return [String] the API key secret (consumer secret)
    # @example Get or set the API key secret
    #   authenticator.api_key_secret = "secret"
    attr_accessor :api_key_secret

    # The access token
    # @api public
    # @return [String] the access token
    # @example Get or set the access token
    #   authenticator.access_token = "token"
    attr_accessor :access_token

    # The access token secret
    # @api public
    # @return [String] the access token secret
    # @example Get or set the access token secret
    #   authenticator.access_token_secret = "token_secret"
    attr_accessor :access_token_secret

    # Initialize a new OAuth1Authenticator
    #
    # @api public
    # @param api_key [String] the API key (consumer key)
    # @param api_key_secret [String] the API key secret (consumer secret)
    # @param access_token [String] the access token
    # @param access_token_secret [String] the access token secret
    # @return [OAuth1Authenticator] a new instance
    # @example Create an OAuth authenticator
    #   authenticator = X::OAuth1Authenticator.new(
    #     api_key: "key",
    #     api_key_secret: "secret",
    #     access_token: "token",
    #     access_token_secret: "token_secret"
    #   )
    def initialize(api_key:, api_key_secret:, access_token:, access_token_secret:)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
    end

    # Generate the OAuth authentication header for a request
    #
    # The signature covers the HTTP method, the URL, its query parameters, and a
    # form-encoded body. Bodies of any other media type, such as the JSON and multipart
    # bodies the X API takes, are not signed.
    #
    # @api public
    # @param request [Net::HTTPRequest] the HTTP request
    # @return [Hash{String => String}] the authentication header with OAuth signature
    # @example Generate an OAuth authentication header
    #   authenticator.header(request)
    def header(request)
      oauth_header = SimpleOAuth::Header.new(request.method, request.uri, form_params(request), credentials)
      {AUTHENTICATION_HEADER => oauth_header.to_s}
    end

    private

    # The credentials, under the names simple_oauth gives them
    # @api private
    # @return [Hash{Symbol => String}] the credentials for signing
    def credentials
      {consumer_key: api_key, consumer_secret: api_key_secret, token: access_token,
       token_secret: access_token_secret}
    end

    # The parameters a form-encoded body contributes to the signature
    #
    # A parameter that repeats is signed once per value, as RFC 5849 Section 3.4.1.3.2 requires,
    # which the key-value pairs preserve.
    #
    # @api private
    # @param request [Net::HTTPRequest] the HTTP request
    # @return [Array<Array(String, String)>] the body parameters, empty unless the body is form-encoded
    def form_params(request)
      URI.decode_www_form(form_body(request))
    end

    # The body whose parameters take part in the signature
    #
    # @api private
    # @param request [Net::HTTPRequest] the HTTP request
    # @return [String] the body, or an empty String when it is not form-encoded
    def form_body(request)
      form_encoded?(request) ? request.body.to_s : ""
    end

    # Check whether a request carries a form-encoded body
    # @api private
    # @param request [Net::HTTPRequest] the HTTP request
    # @return [Boolean] true if the body is form-encoded
    def form_encoded?(request)
      request["Content-Type"].to_s.split(";").first.to_s.strip.downcase.eql?(FORM_CONTENT_TYPE)
    end
  end

  # The name of OAuth1Authenticator before OAuth2Authenticator joined it
  OAuthAuthenticator = OAuth1Authenticator
  deprecate_constant :OAuthAuthenticator
end
