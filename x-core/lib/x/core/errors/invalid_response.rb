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
      # Public, so that code that rescues an InvalidResponse can be tested with one built from the status, headers,
      # and body of a response, or from a Net::HTTP response, as ResponseParser and StreamParser build one. The error
      # names the request, when given its method and URI, as x-core names the request the response answers.
      #
      # @api public
      # @param http_response [Net::HTTPResponse, nil] the HTTP response, or nil for one built of the status, headers,
      #   and body
      # @param status [Integer, nil] the status of the response, from 100 to 599, when it is not given
      # @param headers [Hash{String => String}, nil] the headers of the response, when it is not given
      # @param body [String, nil] the body that is not JSON, which is the body of a response built of the status
      # @param http_method [Symbol, String, nil] the method of the request the response answers, in any case
      # @param uri [URI::Generic, nil] the URI of the request the response answers
      # @return [InvalidResponse] a new instance
      # @raise [ArgumentError] if the HTTP response is given beside a status or headers, or neither it nor a status is
      #   given, or the status is not from 100 to 599, or the headers are not a Hash of names to values
      # @example Create the error of a page a proxy answered with
      #   error = X::InvalidResponse.new(status: 200, headers: {"content-type" => "text/html"}, body: "<html></html>")
      # @example Create an error for a line of a stream
      #   error = X::InvalidResponse.new(http_response: response, body: line, http_method: :get, uri: stream_uri)
      def initialize(http_response: nil, status: nil, headers: nil, body: nil, http_method: nil, uri: nil)
        @body = body
        super(http_response:, status:, headers:, body: (body if http_response.nil?), http_method:, uri:)
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
