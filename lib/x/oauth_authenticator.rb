require "base64"
require "cgi"
require "json"
require "openssl"
require "securerandom"
require "uri"

module X
  # Handles OAuth authentication
  class OauthAuthenticator
    OAUTH_VERSION = "1.0".freeze
    OAUTH_SIGNATURE_METHOD = "HMAC-SHA1".freeze
    OAUTH_SIGNATURE_ALGORITHM = "sha1".freeze

    attr_accessor :api_key, :api_key_secret, :access_token, :access_token_secret

    def initialize(api_key, api_key_secret, access_token, access_token_secret)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
    end

    def header(request)
      method, url, query_params = parse_request(request)
      {"Authorization" => build_oauth_header(method, url, query_params)}
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
        "oauth_timestamp" => Time.now.utc.to_i.to_s,
        "oauth_token" => access_token,
        "oauth_version" => OAUTH_VERSION
      }
    end

    def generate_signature(method, url, params)
      base_string = signature_base_string(method, url, params)
      hmac_signature(base_string)
    end

    def hmac_signature(base_string)
      digest = OpenSSL::Digest.new(OAUTH_SIGNATURE_ALGORITHM)
      hmac = OpenSSL::HMAC.digest(digest, signing_key, base_string)
      Base64.strict_encode64(hmac)
    end

    def signature_base_string(method, url, params)
      "#{method}&#{escape(url)}&#{escape(URI.encode_www_form(params.sort))}"
    end

    def signing_key
      "#{escape(api_key_secret)}&#{escape(access_token_secret)}"
    end

    def format_oauth_header(params)
      "OAuth #{params.sort.map { |k, v| "#{k}=\"#{escape(v.to_s)}\"" }.join(", ")}"
    end

    def escape(value)
      # TODO: Replace CGI.escape with CGI.escapeURIComponent when support for Ruby 3.1 is dropped
      CGI.escape(value.to_s).gsub("+", "%20")
    end
  end
end
