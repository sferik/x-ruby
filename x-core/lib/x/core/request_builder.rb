# frozen_string_literal: true

require "net/http"
require "uri"
require_relative "authenticator"
require_relative "authenticator_request"
require_relative "version"

module X
  module Core
    # Builds HTTP requests for the X API
    #
    # Internal to x-core: Client and StreamingClient build their requests with it.
    #
    # @api private
    class RequestBuilder
      # Default headers for API requests
      DEFAULT_HEADERS = {
        "User-Agent" => "x-ruby/#{Core::VERSION} #{RUBY_ENGINE}/#{RUBY_VERSION} (#{RUBY_PLATFORM})"
      }.freeze
      # The headers of a request that carries a body, which one without a body does not send, since it has no body
      # for a content type to describe
      BODY_HEADERS = {"Content-Type" => "application/json; charset=utf-8"}.freeze
      # Mapping of HTTP method symbols to Net::HTTP classes
      HTTP_METHODS = {
        get: Net::HTTP::Get,
        post: Net::HTTP::Post,
        put: Net::HTTP::Put,
        delete: Net::HTTP::Delete
      }.freeze
      # The HTTP methods a request may be sent again with, since sending one again asks the API for what sending it
      # once did, where a second POST would post a second time
      IDEMPOTENT_METHODS = %i[get put delete].freeze

      # Check whether sending a request again has the same effect as sending it once
      #
      # @api private
      # @param http_method [Symbol] the HTTP method (:get, :post, :put, :delete)
      # @return [Boolean] true for a GET, PUT, or DELETE
      # @example Check whether a post may be sent again
      #   X::Core::RequestBuilder.idempotent?(:post) # => false
      def self.idempotent?(http_method) = IDEMPOTENT_METHODS.include?(http_method)

      # Merge headers over others, as HTTP names them, without regard to case
      #
      # A header of overrides is sent in place of one of headers whose name differs from it in case alone, as
      # "user-agent" is sent in place of "User-Agent", where Hash#merge would keep both and send whichever came last.
      #
      # @api private
      # @param headers [Hash{String, Symbol => String}] the headers overridden
      # @param overrides [Hash{String, Symbol => String}] the headers sent in place of those of the same name
      # @return [Hash{String, Symbol => String}] the headers of both, those of overrides in place of the others
      # @example Replace the User-Agent of a client with one named in lowercase
      #   X::Core::RequestBuilder.merge_headers({"User-Agent" => "a"}, {"user-agent" => "b"}) # => {"user-agent" => "b"}
      def self.merge_headers(headers, overrides)
        headers.reject { |name, _| overrides.any? { |override, _| override.to_s.casecmp?(name.to_s) } }.merge(overrides)
      end

      # Build an HTTP request
      #
      # @api private
      # @param http_method [Symbol] the HTTP method (:get, :post, :put, :delete)
      # @param uri [URI] the request URI
      # @param body [String, nil] the request body
      # @param headers [Hash] additional headers for the request
      # @param authenticator [Authenticator] the authenticator for the request
      # @return [Net::HTTPRequest] the built HTTP request
      # @raise [ArgumentError] if the HTTP method is not supported
      # @example Build a GET request
      #   builder.build(http_method: :get, uri: URI("https://api.x.com/2/users/me"))
      def build(http_method:, uri:, body: nil, headers: {}, authenticator: Authenticator.new)
        request = create_request(http_method:, uri:, body:)
        add_headers(request:, headers:, body:)
        add_authentication(request:, authenticator:)
        request
      end

      private

      # Create an HTTP request
      # @api private
      # @param http_method [Symbol] the HTTP method
      # @param uri [URI] the request URI
      # @param body [String, nil] the request body
      # @return [Net::HTTPRequest] the created request
      def create_request(http_method:, uri:, body:)
        http_method_class = HTTP_METHODS[http_method]

        raise ArgumentError, "Unsupported HTTP method: #{http_method}" unless http_method_class

        escaped_uri = escape_query_params(uri)
        request = http_method_class.new(escaped_uri)
        request.body = body
        request
      end

      # Add authentication to a request
      # @api private
      # @param request [Net::HTTPRequest] the request
      # @param authenticator [Authenticator] the authenticator
      # @return [void]
      def add_authentication(request:, authenticator:)
        authenticator.headers(AuthenticatorRequest.new(request)).each do |key, value|
          request[key] = value
        end
      end

      # Add headers to a request
      #
      # A request that carries a body is given the JSON content type the API takes, which a header of the caller, such
      # as the form content type of a request given form fields, replaces. A request without a body, such as a GET or a
      # DELETE, is given no content type at all, rather than one for a body it does not send.
      #
      # @api private
      # @param request [Net::HTTPRequest] the request
      # @param headers [Hash] additional headers
      # @param body [String, nil] the request body, which decides whether a content type is sent
      # @return [void]
      def add_headers(request:, headers:, body:)
        defaults = body.nil? ? DEFAULT_HEADERS : DEFAULT_HEADERS.merge(BODY_HEADERS)
        RequestBuilder.merge_headers(defaults, headers).each do |key, value|
          request[key] = value
        end
      end

      # Escape query parameters in a URI
      #
      # A parameter without a value, as the flag of "?flag" is, is sent without one, rather than with the empty value
      # of "?flag=", which an endpoint may read otherwise.
      #
      # @api private
      # @param uri [URI] the URI
      # @return [URI] the URI with escaped query parameters
      def escape_query_params(uri)
        URI(uri).tap do |u|
          u.query = URI.encode_www_form(query_pairs(u.query)).gsub("%2C", ",") if u.query
        end
      end

      # Decode the name and value of each parameter of a query
      #
      # A parameter without a value is given nil for one.
      # @api private
      # @param query [String] the query
      # @return [Array<Array(String, String), Array(String, nil)>] the name and value of each parameter
      def query_pairs(query)
        query.split("&").map do |pair|
          name, value = pair.split("=", 2)
          [URI.decode_www_form_component(name.to_s), value&.then { |escaped| URI.decode_www_form_component(escaped) }]
        end
      end
    end
  end
end
