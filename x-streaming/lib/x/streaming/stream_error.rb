# frozen_string_literal: true

require "x/core"
require_relative "error"

module X
  module Streaming
    # Raised for a line of a stream that holds errors and no data
    #
    # A stream sends the problems it has in a line of their own, such as the operational-disconnect X sends before it
    # closes a stream. The line is not an object the stream delivers, so the stream raises this error in place of
    # passing it to its block, whether the objects are Hashes or are built by an object_class.
    #
    # A stream reconnects after a line that holds operational-disconnects alone, as it does after a connection that
    # dropped, and raises this error once it has no reconnects left. After any other problems it stops, and the error
    # reaches the caller, who decides whether to open the stream again. The message names the request, and each
    # problem, and {#problems} holds them, as X::HTTPError#problems holds those of a response the API refused.
    # {#http_method} and {#uri} are the request of the stream.
    #
    # @api public
    # @example Report the problems that stopped a stream
    #   begin
    #     client.streaming.stream("tweets/search/stream") { |post| handle(post) }
    #   rescue X::StreamError => e
    #     warn e.problems.map(&:title).join(", ")
    #   end
    class ::X::StreamError < Streaming::Error
      # The HTTP method the request of the stream was sent with
      #
      # @api public
      # @return [Symbol, nil] the method, as :get, or nil for an error built without one, such as one a test built
      # @example Read the method of the stream
      #   error.http_method # => :get
      attr_reader :http_method

      # The URI the request of the stream was sent to
      #
      # @api public
      # @return [URI::Generic, nil] the URI, or nil for an error built without one
      # @example Read the path of the stream
      #   error.uri.path # => "/2/tweets/search/stream"
      attr_reader :uri

      # The problems the line of the stream held
      #
      # @api public
      # @return [Array<Problem>] the problems, frozen, in the order the line held them
      # @example Read the title of each problem
      #   error.problems.map(&:title) # => ["operational-disconnect"]
      attr_reader :problems

      # Initialize a new StreamError
      #
      # Public, so that code that rescues a StreamError can be tested with one built by hand, as StreamParser builds one
      # for a line of a stream, and raised with a message alone, as any exception is. The message is the one given, or
      # else the title and detail of each problem, and names the request, when given its method and URI, as the errors
      # of x-core name the request that raised them.
      #
      # @api public
      # @param message [String, nil] the message, or nil for the one the problems give
      # @param problems [Array<Problem>] the problems the line held
      # @param http_method [Symbol, String, nil] the method of the request of the stream, in any case
      # @param uri [URI::Generic, nil] the URI of the request of the stream
      # @return [StreamError] a new instance
      # @example Create an error
      #   error = X::StreamError.new(problems: X::Problem.all_from(body), http_method: :get, uri: stream_uri)
      # @example Raise the error with a message alone, as a test stub may
      #   raise X::StreamError, "The stream dropped"
      def initialize(message = nil, problems: [], http_method: nil, uri: nil)
        @problems = problems.dup.freeze
        @http_method = http_method&.downcase&.to_sym
        @uri = uri
        super(naming_request(message || describe(problems)))
      end

      private

      # The message, led by the method and path of the request it names, if any
      #
      # It names the request as an error of x-core does, as "GET /2/tweets/search/stream: operational-disconnect". An
      # error that says nothing of what went wrong names no request, so that its message is the name of its class, as
      # that of any exception raised with no message is.
      #
      # @api private
      # @param message [String, nil] what went wrong, or nil for nothing
      # @return [String, nil] the message, or nil for none
      def naming_request(message)
        http_method, uri = @http_method, @uri
        return message unless http_method && uri && message

        path = uri.path #: String
        "#{http_method.upcase} #{path.empty? ? "/" : path}: #{message}"
      end
    end
  end
end
