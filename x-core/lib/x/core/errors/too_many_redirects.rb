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

      # Initialize a new TooManyRedirects
      #
      # Public, so that code that rescues a TooManyRedirects can be tested with one built by hand, as RedirectHandler
      # builds one. The error names the request, when given its method and URI, as x-core names the request whose
      # redirect was one too many.
      #
      # @api public
      # @param message [String] what went wrong
      # @param http_method [Symbol, String, nil] the method of the request whose redirect was one too many, in any case
      # @param uri [URI::Generic, nil] the URI of the request whose redirect was one too many
      # @return [TooManyRedirects] a new instance
      # @example Create an error
      #   error = X::TooManyRedirects.new("Too many redirects", http_method: :get, uri: URI("https://api.x.com/2/users/me"))
      def initialize(message, http_method: nil, uri: nil)
        name_request(http_method, uri)
        super(message_naming_request(message))
      end
    end
  end
end
