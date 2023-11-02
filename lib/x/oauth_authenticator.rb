require "base64"
require "json"
require "openssl"
require "securerandom"
require "uri"
require_relative "authenticator"
require_relative "cgi"

module X
  class OAuthAuthenticator < Authenticator
    OAUTH_VERSION = "1.0".freeze
    OAUTH_SIGNATURE_METHOD = "HMAC-SHA1".freeze
    OAUTH_SIGNATURE_ALGORITHM = "sha1".freeze

    attr_accessor :api_key, :api_key_secret, :access_token, :access_token_secret

    def initialize(api_key:, api_key_secret:, access_token:, access_token_secret:) # rubocop:disable Lint/MissingSuper
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
    end

    def header(request)
      method, url, query_params = parse_request(request)
      {AUTHENTICATION_HEADER => build_oauth_header(method, url, query_params)}
    end

    private

    def parse_request(request)
      uri = request.uri
      query_params = parse_query_params(uri.query.to_s)
      [request.method, uri_without_query(uri), query_params]
    end

    def parse_query_params(query_string)
      URI.decode_www_form(query_string).to_h
    end

    def uri_without_query(uri)
      uri.to_s.chomp("?#{uri.query}")
    end

    def build_oauth_header(method, url, query_params)
      oauth_params = default_oauth_params
      all_params = query_params.merge(oauth_params)
      oauth_params["oauth_signature"] = generate_signature(method, url, all_params)
      format_oauth_header(oauth_params)
    end

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

    def generate_signature(method, url, params)
      base_string = signature_base_string(method, url, params)
      hmac_signature(base_string)
    end

    def hmac_signature(base_string)
      hmac = OpenSSL::HMAC.digest(OAUTH_SIGNATURE_ALGORITHM, signing_key, base_string)
      Base64.strict_encode64(hmac)
    end

    def signature_base_string(method, url, params)
      "#{method}&#{CGI.escape(url)}&#{CGI.escape(CGI.escape_params(params.sort))}"
    end

    def signing_key
      "#{api_key_secret}&#{access_token_secret}"
    end

    def format_oauth_header(params)
      "OAuth #{params.sort.map { |k, v| "#{k}=\"#{CGI.escape(v)}\"" }.join(", ")}"
    end
  end
end
