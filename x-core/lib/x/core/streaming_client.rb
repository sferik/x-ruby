require "forwardable"
require "uri"
require_relative "connection"
require_relative "reconnect_handler"
require_relative "request_builder"
require_relative "request_encoding"
require_relative "response"
require_relative "response_parser"
require_relative "stream_parser"

module X
  # A client for the streaming endpoints, which hold a connection open rather than answer a request
  #
  # A stream reads until it is interrupted, so it reads with a short timeout, reconnects when it drops, and
  # authenticates as the app, which the streaming endpoints require. It takes its credentials, base URL, parsing
  # classes, and on_response hook from the client it was built from, and keeps the rest of its settings itself.
  #
  # @api public
  class StreamingClient
    extend Forwardable
    include RequestEncoding

    # Default timeout for reading from a stream in seconds, the interval of the keep-alive X sends
    DEFAULT_READ_TIMEOUT = 20 # seconds

    # The client the stream authenticates and parses with
    # @api public
    # @return [Client] the client
    # @example Read the base URL of a stream
    #   streaming_client.client.base_url
    attr_reader :client

    def_delegators :@connection, :open_timeout, :read_timeout, :write_timeout, :proxy_url, :debug_output
    def_delegators :@connection, :open_timeout=, :read_timeout=, :write_timeout=, :proxy_url=, :debug_output=
    def_delegators :@reconnect_handler, :max_reconnects, :max_reconnects=

    # Initialize a client for the streaming endpoints
    #
    # @api public
    # @param client [Client] the client whose credentials, base URL, and settings the stream uses
    # @param read_timeout [Integer] the timeout for reading from a stream in seconds
    # @param max_reconnects [Integer, Float] the maximum number of times in a row to reconnect a stream that drops
    #   without delivering an object, or Float::INFINITY, the default, for no limit
    # @return [StreamingClient] a new instance
    # @example Create a streaming client
    #   streaming_client = X::StreamingClient.new(client, max_reconnects: 5)
    def initialize(client, read_timeout: DEFAULT_READ_TIMEOUT, max_reconnects: ReconnectHandler::DEFAULT_MAX_RECONNECTS)
      @client = client
      @connection = Connection.new(open_timeout: client.open_timeout, read_timeout:, write_timeout: client.write_timeout,
        debug_output: client.debug_output, proxy_url: client.proxy_url)
      @reconnect_handler = ReconnectHandler.new(max_reconnects:)
      @request_builder = RequestBuilder.new
      @response_parser = ResponseParser.new
      @stream_parser = StreamParser.new
    end

    # Summarize the streaming client for the console without revealing credentials
    #
    # @api public
    # @return [String] the class name and the client it streams with
    # @example Inspect a streaming client
    #   streaming_client.inspect # => #<X::StreamingClient client=#<X::Client ...>>
    def inspect
      "#<#{self.class} client=#{client.inspect}>"
    end

    # Stream data from the X API
    #
    # The stream endpoints take app-only authentication, so a client that signs with OAuth 1.0a streams with the
    # bearer token its app_only client holds. A stream that drops reconnects, backing off as X recommends, up to
    # max_reconnects times in a row. The API bills each object a stream delivers, so the client's on_response
    # receives each one, as well as a failed response.
    #
    # @api public
    # @param endpoint [String] the streaming API endpoint
    # @param params [Hash, nil] query parameters appended to the endpoint
    # @param headers [Hash] additional headers for the request
    # @param array_class [Class] the class for parsing JSON arrays
    # @param object_class [Class] the class for parsing JSON objects, or one that responds to from_response
    #   and builds objects from the whole response (see {ResponseParser#decode})
    # @yield [Hash, Array] each parsed JSON object from the stream
    # @return [nil] once the stream ends with no reconnects left
    # @raise [HTTPError] if the response is not successful and the stream may not reconnect
    # @example Stream filtered posts
    #   streaming_client.stream("tweets/search/stream") { |post| puts post }
    def stream(endpoint, params: nil, headers: {}, array_class: client.default_array_class,
      object_class: client.default_object_class, &block)
      uri = URI.join(client.base_url, endpoint_with(endpoint, params))
      @reconnect_handler.handle(block) do |deliver|
        @connection.perform_stream(request: request_for(uri, headers)) do |response|
          @stream_parser.process(response:, response_parser: @response_parser, array_class:, object_class:, client:,
            on_body: ->(body = nil) { report(uri, response, body) }, &deliver)
        end
      end
    end

    private

    # Build a request that authenticates as the app
    # @api private
    # @param uri [URI::Generic] the URI of the stream
    # @param headers [Hash] additional headers for the request
    # @return [Net::HTTPRequest] the request
    def request_for(uri, headers)
      @request_builder.build(http_method: :get, uri:, headers:, authenticator: client.app_only.authenticator)
    end

    # Pass a response, or one object of a stream, to the client's on_response
    # @api private
    # @param uri [URI::Generic] the URI of the stream
    # @param response [Net::HTTPResponse] the HTTP response
    # @param body [String, nil] the object the stream delivered, or nil for the whole body
    # @return [void]
    def report(uri, response, body)
      client.on_response&.call(Response.new(:get, uri, response, body:))
    end
  end
end
