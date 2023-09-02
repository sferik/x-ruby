require "base64"
require "cgi"
require "json"
require "openssl"
require "securerandom"
require "uri"

module X
  # Handles OAuth authentication
  class Authenticator
    attr_accessor :api_key, :api_key_secret, :access_token, :access_token_secret

    OAUTH_VERSION = "1.0".freeze
    OAUTH_SIGNATURE_METHOD = "HMAC-SHA1".freeze

    def initialize(api_key, api_key_secret, access_token, access_token_secret)
      @api_key = api_key
      @api_key_secret = api_key_secret
      @access_token = access_token
      @access_token_secret = access_token_secret
    end

    def sign!(request)
      method = request.method
      uri, query_params = split_uri(request.uri)
      request.add_field("Authorization", oauth_header(method, uri, query_params))
    end

    private

    def split_uri(uri)
      uri_base = uri.path.to_s
      query_params = URI.decode_www_form(uri.query.to_s).to_h
      [uri_base, query_params]
    end

    def oauth_header(method, uri, query_params)
      oauth_params = default_oauth_params
      all_params = query_params.merge(oauth_params)
      oauth_params["oauth_signature"] = generate_signature(method, uri, all_params)
      formatted_oauth_header(oauth_params)
    end

    def default_oauth_params
      {
        "oauth_consumer_key" => @api_key,
        "oauth_nonce" => SecureRandom.hex,
        "oauth_signature_method" => OAUTH_SIGNATURE_METHOD,
        "oauth_timestamp" => Time.now.utc.to_i.to_s,
        "oauth_token" => @access_token,
        "oauth_version" => OAUTH_VERSION
      }
    end

    def generate_signature(method, uri, params)
      Base64.encode64(OpenSSL::HMAC.digest(
        OpenSSL::Digest.new("sha1"),
        signing_key,
        signature_base_string(method, uri, params)
      )).chomp
    end

    def signature_base_string(method, uri, params)
      encoded_params = encode_params(params)
      "#{method}&#{CGI.escape(uri)}&#{CGI.escape(encoded_params)}"
    end

    def encode_params(params)
      # TODO: Replace CGI.escape with CGI.escapeURIComponent when support for Ruby 3.1 is dropped
      params.sort.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join("&").gsub("+", "%20")
    end

    def signing_key
      "#{CGI.escape(@api_key_secret)}&#{CGI.escape(@access_token_secret)}"
    end

    def formatted_oauth_header(params)
      "OAuth #{params.sort.map { |k, v| "#{k}=\"#{CGI.escape(v.to_s)}\"" }.join(", ")}"
    end
  end
end
