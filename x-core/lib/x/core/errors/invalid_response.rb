# frozen_string_literal: true

require_relative "http_error"

module X
  module Core
    # Error raised for a successful response whose body is not JSON, such as the page of a proxy or captive portal
    #
    # It is an X::HTTPError, so that code that rescues the failures of a response reads it as it reads any other:
    # the status is {#status}, the headers are {#headers}, the body is {#body}, and {#http_method} and {#uri} are the
    # request it answered. A body that is not JSON describes no problem, so {#problem} is nil and {#problems} empty.
    #
    # @api public
    class ::X::InvalidResponse < ::X::HTTPError
      # The body that is not JSON: the whole body of a response, or the line of a stream
      #
      # The body of a stream can be read only as it arrives, so an error raised for a line of a stream holds that line.
      # It is tagged UTF-8, as {Response#body} is, and keeps the bytes of a body that is not valid UTF-8.
      #
      # @api public
      # @return [String, nil] the body, or the line of a stream, tagged UTF-8, or nil for an error built without one
      # @example Read the body that could not be parsed
      #   error.body
      attr_reader :body

      # Initialize a new InvalidResponse
      #
      # Public, so that code that rescues an InvalidResponse can be tested with one built from a Net::HTTP response, as
      # ResponseParser and StreamParser build one. The error names the request, when given its method and URI, as
      # x-core names the request the response answers.
      #
      # @api public
      # @param http_response [Net::HTTPResponse] the HTTP response
      # @param body [String, nil] the body that is not JSON
      # @param http_method [Symbol, String, nil] the method of the request the response answers, in any case
      # @param uri [URI::Generic, nil] the URI of the request the response answers
      # @return [InvalidResponse] a new instance
      # @example Create an error
      #   error = X::InvalidResponse.new(http_response: response, body: response.body)
      # @example Create an error for a line of a stream
      #   error = X::InvalidResponse.new(http_response: response, body: line, http_method: :get, uri: stream_uri)
      def initialize(http_response:, body: nil, http_method: nil, uri: nil)
        @body = body
        super(http_response:, http_method:, uri:)
      end

      private

      # The message of the error, which says the body is not JSON
      #
      # It names what the response says the body is instead, since a body that is not JSON holds no message.
      #
      # @api private
      # @param _body [Hash{String => Object}] the parsed body, which is empty
      # @return [String] the message
      def message_from(_body) = "The body of the #{http_response.code} response is not JSON (#{http_response["content-type"] || "no content type"})"
    end
  end
end
