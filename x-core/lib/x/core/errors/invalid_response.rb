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
      # An error given no body holds the body of its response, as {HTTPError#body} does, once that response has been
      # read whole. The body of a response that has not been read, as that of a stream still arriving, is never read
      # for it, since reading it would wait for the rest of the stream, or take the lines the stream has yet to read.
      #
      # @api public
      # @return [String, nil] the body, or the line of a stream, tagged UTF-8, or else the body of the response once it
      #   has been read whole, or nil for an error of a response that has not been, or that has none
      # @example Read the body that could not be parsed
      #   error.body
      def body = @body || body_read

      # Initialize a new InvalidResponse
      #
      # Public, so that code that rescues an InvalidResponse can be tested with one built from the status, headers,
      # and body of a response, or from a Net::HTTP response, as ResponseParser and the stream of x-streams build one. The error
      # names the request, when given its method and URI, as x-core names the request the response answers.
      #
      # It can be raised as any other exception is, as in raise X::InvalidResponse, and is built with a status of 200
      # when it is given neither a response nor a status, as HTTPError states.
      #
      # @api public
      # @param message [String, nil] the message, or nil for the one that names the status and content type
      # @param http_response [Net::HTTPResponse, nil] the response of the transport, an escape hatch as
      #   {#http_response} is, whose class is not covered by the compatibility promise of 1.x, or nil for one built of
      #   the status, headers, and body, which every release of 1.x takes
      # @param status [Integer, nil] the status of the response, from 100 to 599, when it is not given, or nil for 200
      # @param headers [Hash{String => String}, nil] the headers of the response, when it is not given
      # @param body [String, nil] the body that is not JSON, which is the body of a response built of the status
      # @param http_method [Symbol, String, nil] the method of the request the response answers, in any case
      # @param uri [URI::Generic, nil] the URI of the request the response answers
      # @return [InvalidResponse] a new instance
      # @raise [ArgumentError] if the HTTP response is given beside a status or headers, or the status is not from 100
      #   to 599, or the headers are not a Hash of names to values
      # @example Create the error of a page a proxy answered with
      #   error = X::InvalidResponse.new(status: 200, headers: {"content-type" => "text/html"}, body: "<html></html>")
      # @example Create an error for a line of a stream
      #   error = X::InvalidResponse.new(http_response: response, body: line, http_method: :get, uri: stream_uri)
      def initialize(message = nil, http_response: nil, status: nil, headers: nil, body: nil, http_method: nil, uri: nil)
        @body = body.dup&.force_encoding(Encoding::UTF_8)
        super(message, http_response:, status:, headers:, body: (body if http_response.nil?), http_method:, uri:)
      end

      # The status an InvalidResponse is built with by default
      #
      # It is the status one given neither a response nor a status is built with. A body that is not JSON is raised for a response that succeeded, so it is 200 OK.
      #
      # @api private
      # @return [Integer] the status, 200
      # @example Get the status of an InvalidResponse
      #   X::InvalidResponse.__send__(:default_status) # => 200
      def self.default_status = 200
      private_class_method :default_status

      private

      # The body of the response, if it has been read whole
      #
      # A response read whole holds its body as a String, where one read in chunks, as a stream is, holds what it read
      # them with, and one not yet read reads its body when asked for it, which this never asks it.
      #
      # @api private
      # @return [String, nil] the body, or nil for a response not yet read, read in chunks, or without one
      def body_read
        String.try_convert(http_response.body) if http_response.instance_variable_get(:@read)
      end

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
