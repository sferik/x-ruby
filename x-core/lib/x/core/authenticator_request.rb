# frozen_string_literal: true

module X
  module Core
    # The request an authenticator is passed: what it may read of the request a client is about to send
    #
    # It answers the four methods an authenticator is guaranteed, and no more, so that an authenticator of your own
    # reads nothing of the Net::HTTPRequest a client sends that a later version of 1.x, which may send another, could
    # take away.
    #
    # Internal to x-core: RequestBuilder passes one to the authenticator of each request it builds.
    #
    # @api private
    class AuthenticatorRequest
      # Initialize the request an authenticator reads
      # @api private
      # @param request [Net::HTTPRequest] the request a client is about to send
      # @return [AuthenticatorRequest] a new instance
      # @example Pass a request to an authenticator
      #   authenticator.headers(X::Core::AuthenticatorRequest.new(request))
      def initialize(request)
        @request = request
      end

      # The HTTP method the request is sent with
      # @api private
      # @return [Symbol] the method, as :get, :post, :put, or :delete
      # @example Read the method
      #   request.http_method # => :post
      def http_method = @request.method.downcase.to_sym

      # The URI the request is sent to, query included
      # @api private
      # @return [URI::Generic] the URI
      # @example Read the URI
      #   request.uri # => #<URI::HTTPS https://api.x.com/2/tweets>
      def uri = @request.uri

      # The body the request sends
      # @api private
      # @return [String, nil] the body, or nil for none
      # @example Read the body
      #   request.body # => "{\"text\":\"Hello\"}"
      def body = @request.body

      # The value of a header the request sends
      # @api private
      # @param name [String] the name of the header, in any case
      # @return [String, nil] the value, or nil for a header the request does not send
      # @example Read the content type
      #   request["Content-Type"] # => "application/json; charset=utf-8"
      def [](name) = @request[name]
    end
    private_constant :AuthenticatorRequest
  end
end
