# frozen_string_literal: true

require_relative "error"
require_relative "../request_context"

module X
  # Raised for a response that redirected more times than the client's max_redirects allows
  #
  # The message names the request whose redirect was one too many, and {#http_method} and {#uri} read it: the
  # request that redirect answered, which is the one a client sent last, rather than the one it was first asked for.
  #
  # @api public
  # @example Tell an endpoint that redirects in a loop from the others
  #   rescue X::TooManyRedirects => e
  #     logger.warn("#{e.uri} keeps redirecting")
  class TooManyRedirects < Error
    include Core::RequestContext

    # Initialize a new TooManyRedirects
    #
    # Internal to x-core: RedirectHandler raises it, and it takes the Net::HTTP request that was redirected, so that
    # it can change within 1.x, as that request may.
    #
    # @api private
    # @param message [String] what went wrong
    # @param request [Net::HTTPRequest, nil] the request whose redirect was one too many, which the error names
    # @return [TooManyRedirects] a new instance
    # @example Create an error
    #   error = X::TooManyRedirects.new("Too many redirects", request: request)
    def initialize(message, request: nil)
      name_request(request)
      super(message_naming_request(message))
    end
  end
end
