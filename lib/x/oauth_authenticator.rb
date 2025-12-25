require "base64"
require "cgi/escape"
require "json"
require "openssl"
require "securerandom"
require "uri"
require_relative "authenticator"

module X
  # Authenticator for OAuth 1.0a authentication
  # @api public
  class OAuthAuthenticator < Authenticator
    # OAuth version
    OAUTH_VERSION = "1.0".freeze
    # OAuth signature method
    OAUTH_SIGNATURE_METHOD = "HMAC-SHA1".freeze
    # OAuth signature algorithm
    OAUTH_SIGNATURE_ALGORITHM = "sha1".freeze

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

    # Initialize a new OAuthAuthenticator
    #
    # @api public
    # @param api_key [String] the API key (consumer key)
    # @param api_key_secret [String] the API key secret (consumer secret)
    # @param access_token [String] the access token
    # @param access_token_secret [String] the access token secret
    # @return [OAuthAuthenticator] a new instance
    # @example Create an OAuth authenticator
    #   authenticator = X::OAuthAuthenticator.new(
    #     api_key: "key",
    #     api_key_secret: "secret",
    #     access_token: "token",
    #     access_token_secret: "token_secret"
    #   )
    def initialize(api_key:, api_key_secret:, access_token:, access_token_secret:) # rubocop:disable Lint/MissingSuper
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
    end

    # Generate the OAuth authentication header for a request
    #
    # @api public
    # @param request [Net::HTTPRequest] the HTTP request
    # @return [Hash{String => String}] the authentication header with OAuth signature
    # @example Generate an OAuth authentication header
    #   authenticator.header(request)
    def header(request)
      method, url, query_params = parse_request(request)
      {AUTHENTICATION_HEADER => build_oauth_header(method, url, query_params)}
    end

    private

    # Parse the request to extract method, URL, and query parameters
    # @api private
    # @param request [Net::HTTPRequest] the HTTP request
    # @return [Array<String, String, Hash>] the method, URL, and query parameters
    def parse_request(request)
      uri = request.uri
      query_params = parse_query_params(uri.query.to_s)
      [request.method, uri_without_query(uri), query_params]
    end

    # Parse query parameters from a query string
    # @api private
    # @param query_string [String] the query string
    # @return [Hash] the parsed query parameters
    def parse_query_params(query_string)
      URI.decode_www_form(query_string).to_h
    end

    # Get the URI without query parameters
    # @api private
    # @param uri [URI] the URI
    # @return [String] the URI without query parameters
    def uri_without_query(uri)
      "#{uri.scheme}://#{uri.host}#{uri.path}"
    end

    # Build the OAuth header value
    # @api private
    # @param method [String] the HTTP method
    # @param url [String] the request URL
    # @param query_params [Hash] the query parameters
    # @return [String] the OAuth header value
    def build_oauth_header(method, url, query_params)
      oauth_params = default_oauth_params
      all_params = query_params.merge(oauth_params)
      oauth_params["oauth_signature"] = generate_signature(method, url, all_params)
      format_oauth_header(oauth_params)
    end

    # Get the default OAuth parameters
    # @api private
    # @return [Hash] the default OAuth parameters
    def default_oauth_params
      {
        "oauth_consumer_key" => api_key,
        "oauth_nonce" => SecureRandom.hex,
        "oauth_signature_method" => OAUTH_SIGNATURE_METHOD,
        "oauth_timestamp" => Integer(Time.now).to_s,
        "oauth_token" => access_token,
        "oauth_version" => OAUTH_VERSION
      }
    end

    # Generate the OAuth signature
    # @api private
    # @param method [String] the HTTP method
    # @param url [String] the request URL
    # @param params [Hash] the combined parameters
    # @return [String] the OAuth signature
    def generate_signature(method, url, params)
      base_string = signature_base_string(method, url, params)
      hmac_signature(base_string)
    end

    # Generate the HMAC signature
    # @api private
    # @param base_string [String] the signature base string
    # @return [String] the Base64-encoded HMAC signature
    def hmac_signature(base_string)
      hmac = OpenSSL::HMAC.digest(OAUTH_SIGNATURE_ALGORITHM, signing_key, base_string)
      Base64.strict_encode64(hmac)
    end

    # Build the signature base string
    # @api private
    # @param method [String] the HTTP method
    # @param url [String] the request URL
    # @param params [Hash] the combined parameters
    # @return [String] the signature base string
    def signature_base_string(method, url, params)
      "#{method}&#{CGI.escapeURIComponent(url)}&#{CGI.escapeURIComponent(URI.encode_www_form(params.sort).gsub("+", "%20"))}"
    end

    # Get the signing key
    # @api private
    # @return [String] the signing key
    def signing_key
      "#{api_key_secret}&#{access_token_secret}"
    end

    # Format the OAuth header value
    # @api private
    # @param params [Hash] the OAuth parameters
    # @return [String] the formatted OAuth header value
    def format_oauth_header(params)
      "OAuth #{params.sort.map { |k, v| "#{k}=\"#{CGI.escapeURIComponent(v)}\"" }.join(", ")}"
    end
  end
end
