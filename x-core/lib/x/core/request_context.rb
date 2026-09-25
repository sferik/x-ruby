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
      # The query of a request target, which the message of an error leaves out
      QUERY = /\?.*\z/
      private_constant :QUERY

      # The HTTP method the request was sent with
      #
      # @api public
      # @return [Symbol, nil] the method, as :get, :post, :put, or :delete, or nil for an error built without a
      #   request, such as one a test built from a response alone
      # @example Tell a read that failed from a write
      #   writes_failed += 1 unless error.http_method.eql?(:get)
      attr_reader :http_method

      # The URI the request was sent to
      #
      # @api public
      # @return [URI::Generic, nil] the URI, or nil for an error built without a request
      # @example Count the failures of each endpoint
      #   failures[error.uri.path] += 1
      attr_reader :uri

      private

      # Read the method, URI, and line of the request an error names
      #
      # The line is the method and the path the request was sent for, which Net::HTTP reads off the URI, so that a
      # URI naming a host and nothing else is named as the request for its root that it was sent as.
      #
      # @api private
      # @param request [Net::HTTPRequest, nil] the request that failed, or nil for an error built without one
      # @return [void]
      def name_request(request)
        @http_method = request&.method&.downcase&.to_sym
        @uri = request&.uri
        @request_line = request && "#{request.method} #{request.path.sub(QUERY, "")}"
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
  end
end
