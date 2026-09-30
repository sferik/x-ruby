# frozen_string_literal: true

module X
  module Core
    # The request an error names: the method it was sent with and the URI it was sent to
    #
    # An error says what went wrong, and code that makes many requests needs to know which request it went wrong
    # for. The errors a request raises are built with it, so each of them reads the method and URI of that request,
    # and names it in its message, as "GET /2/users/1: Could not find user" does.
    #
    # A request that names another host is not followed there with the credentials of the API, so the URI is the
    # one the request was sent to, whole, rather than a path read against a base URL.
    #
    # Internal to x-core: the errors of a request include it, and the parsers and the connection build those
    # errors with the request that raised them.
    #
    # @api private
    module RequestContext
      # The HTTP method the request was sent with
      #
      # @api public
      # @return [Symbol, nil] the method, as :get, :post, :put, or :delete, or nil for an error built without one,
      #   such as one a test built from a response alone
      # @example Tell a read that failed from a write
      #   writes_failed += 1 unless error.http_method.eql?(:get)
      attr_reader :http_method

      # The URI the request was sent to
      #
      # @api public
      # @return [URI::Generic, nil] the URI, or nil for an error built without one
      # @example Count the failures of each endpoint
      #   failures[error.uri.path] += 1
      attr_reader :uri

      # The method and URI of a request, as the keywords of an error that names it
      #
      # The errors take the method and URI of a request rather than the Net::HTTP request itself, so that code that
      # builds one, as a test does, depends on neither Net::HTTP nor the way x-core sends a request.
      #
      # @api private
      # @param request [Net::HTTPRequest, nil] the request that failed, or nil for none
      # @return [Hash{Symbol => Object}, nil] the http_method and uri of the request, or nil, which splats no keywords,
      #   for none
      # @example The keywords of a request
      #   RequestContext.of(request) # => {http_method: "GET", uri: #<URI::HTTPS https://api.x.com/2/users/me>}
      def self.of(request) = request && {http_method: request.method, uri: request.uri}

      private

      # Read the method, URI, and line of the request an error names
      #
      # The line is the method and the path the request was sent for, which Net::HTTP reads off the URI, so that a
      # URI naming a host and nothing else is named as the request for its root that it was sent as.
      #
      # @api private
      # @param http_method [Symbol, String, nil] the method the request was sent with, in any case, or nil for none
      # @param uri [URI::Generic, nil] the URI the request was sent to, or nil for none
      # @return [void]
      def name_request(http_method, uri)
        @http_method = http_method&.downcase&.to_sym
        @uri = uri
        return unless http_method && uri

        path = uri.path #: String
        @request_line = "#{http_method.upcase} #{path.empty? ? "/" : path}"
      end

      # The message of an error, behind the request it names
      #
      # The query is left out, since the object layer asks for every field of a resource, which makes a query
      # longer than the rest of the message.
      #
      # @api private
      # @param message [String] what went wrong
      # @return [String] the message, behind the method and path of the request an error names, or as it is for an
      #   error that names none
      def message_naming_request(message)
        line = @request_line
        line.nil? ? message : "#{line}: #{message}"
      end
    end
    private_constant :RequestContext
  end
end
