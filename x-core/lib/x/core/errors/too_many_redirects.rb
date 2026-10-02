# frozen_string_literal: true

require_relative "error"
require_relative "../request_context"

module X
  module Core
    # Raised for a response that redirected more times than the client's max_redirects allows
    #
    # The message names the request whose redirect was one too many, and {#http_method} and {#uri} read it: the
    # request that redirect answered, which is the one a client sent last, rather than the one it was first asked for.
    #
    # @api public
    # @example Tell an endpoint that redirects in a loop from the others
    #   rescue X::TooManyRedirects => e
    #     logger.warn("#{e.uri} keeps redirecting")
    class ::X::TooManyRedirects < Error
      include RequestContext

      # @!method http_method
      #   The HTTP method the request whose redirect was one too many was sent with
      #   @api public
      #   @return [Symbol, nil] the method, as :get, :post, :put, or :delete, or nil for an error built without one
      #   @example Tell a read that redirected in a loop from a write
      #     writes_failed += 1 unless error.http_method.eql?(:get)
      # @!method uri
      #   The URI the request whose redirect was one too many was sent to
      #   @api public
      #   @return [URI::Generic, nil] the URI, or nil for an error built without one
      #   @example Get the path that keeps redirecting
      #     error.uri.path # => "/2/users/me"

      # Initialize a new TooManyRedirects
      #
      # Public, so that code that rescues a TooManyRedirects can be tested with one built by hand, as RedirectHandler
      # builds one, or raised with no message, as any exception is. The error names the request, when given its method
      # and URI, as x-core names the request whose redirect was one too many.
      #
      # @api public
      # @param message [String, nil] what went wrong, or nil for the name of the class, as an exception raised with no
      #   message is named, which names no request
      # @param http_method [Symbol, String, nil] the method of the request whose redirect was one too many, in any case
      # @param uri [URI::Generic, nil] the URI of the request whose redirect was one too many
      # @return [TooManyRedirects] a new instance
      # @example Create an error
      #   error = X::TooManyRedirects.new("Too many redirects", http_method: :get, uri: URI("https://api.x.com/2/users/me"))
      def initialize(message = nil, http_method: nil, uri: nil)
        name_request(http_method, uri)
        super(message && message_naming_request(message))
      end
    end
  end
end
