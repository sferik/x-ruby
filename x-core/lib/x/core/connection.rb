# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"
require "zlib"
require_relative "connection_pool"
require_relative "connection_proxy"
require_relative "connection_request"
require_relative "proxy_setting"
require_relative "request_context"
require_relative "setting_validator"
require_relative "errors/network_error"
require_relative "errors/callback_error"

module X
  module Core
    # Manages HTTP connections to the X API
    #
    # Internal to x-core: Client, StreamingClient, and the authenticators and authorization that fetch tokens send
    # their requests with it, so that it can change within 1.x. Configure it through the settings of Client, such as
    # proxy_url and the timeouts.
    #
    # Requests keep their connections open for the next request to the same host, which saves opening a TCP and
    # TLS connection each time. A stream opens a connection of its own, which it holds for as long as it reads.
    #
    # A connection keeps the settings it was built with for as long as it lives, as {Client} does, so a request never
    # opens a connection under a setting another thread is halfway through changing. Build another connection to
    # reach the API differently.
    #
    # @api private
    class Connection
      include ConnectionProxy
      include ConnectionRequest
      include ProxySetting

      # Default timeout for opening connections in seconds; opening a connection is a TCP handshake and a TLS one,
      # which a reachable host finishes in well under a second, so a host that takes longer is one a request waits
      # on rather than reaches, and it is given less time than reading a response, which an endpoint may be slow to
      # send
      DEFAULT_OPEN_TIMEOUT = 10 # seconds
      # Default timeout for reading responses in seconds
      DEFAULT_READ_TIMEOUT = 60 # seconds
      # Default timeout for writing requests in seconds
      DEFAULT_WRITE_TIMEOUT = 60 # seconds
      # Default time to keep a connection open for the next request to the same host, in seconds; X holds an idle
      # connection open for more than five minutes, so a connection closed within this time was closed by a proxy
      DEFAULT_KEEP_ALIVE_TIMEOUT = 30 # seconds
      # The settings a connection is opened under, which a connection that shares the pool of another holds the same of
      SETTINGS = %i[open_timeout read_timeout write_timeout keep_alive_timeout debug_output proxy_url].freeze
      private_constant :SETTINGS
      # The timeout for opening connections in seconds
      # @api private
      # @return [Integer, Float, nil] the timeout for opening connections in seconds, or nil for none
      # @example Get the open timeout
      #   connection.open_timeout # => 10
      attr_reader :open_timeout

      # The timeout for reading responses in seconds
      # @api private
      # @return [Integer, Float, nil] the timeout for reading responses in seconds, or nil for none
      # @example Get the read timeout
      #   connection.read_timeout # => 60
      attr_reader :read_timeout

      # The timeout for writing requests in seconds
      # @api private
      # @return [Integer, Float, nil] the timeout for writing requests in seconds, or nil for none
      # @example Get the write timeout
      #   connection.write_timeout # => 60
      attr_reader :write_timeout

      # The IO object for debug output
      # @api private
      # @return [IO, #<<, nil] the IO object for debug output, or anything else that takes a String with <<, such as
      #   a Logger, or nil for none
      # @example Get the debug output
      #   connection.debug_output
      attr_reader :debug_output

      # The time to keep a connection open for the next request, in seconds
      # @api private
      # @return [Integer, Float] the time in seconds
      # @example Get the keep-alive timeout
      #   connection.keep_alive_timeout # => 30
      attr_reader :keep_alive_timeout

      # Initialize a new connection
      #
      # @api private
      # @param open_timeout [Integer, Float, nil] the timeout for opening connections in seconds, or nil for none
      # @param read_timeout [Integer, Float, nil] the timeout for reading responses in seconds, or nil for none
      # @param write_timeout [Integer, Float, nil] the timeout for writing requests in seconds, or nil for none
      # @param keep_alive_timeout [Integer, Float] the time to keep a connection open for the next request to the same
      #   host, in seconds, which a proxy that closes idle connections sooner than X does may need lowered
      # @param debug_output [IO, #<<, nil] the IO object for debug output, or anything else that takes a String with <<,
      #   such as a StringIO or a Logger
      # @param proxy_url [String, URI::Generic, nil] the proxy URL for requests
      # @return [Connection] a new connection instance
      # @raise [ArgumentError] if a timeout is neither a finite number of seconds of at least 0 nor, for any but
      #   keep_alive_timeout, nil
      # @example Create a connection with default settings
      #   connection = X::Core::Connection.new
      # @example Create a connection with custom timeouts
      #   connection = X::Core::Connection.new(open_timeout: 30, read_timeout: 30)
      def initialize(open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT,
        write_timeout: DEFAULT_WRITE_TIMEOUT, keep_alive_timeout: DEFAULT_KEEP_ALIVE_TIMEOUT, debug_output: nil, proxy_url: nil)
        @open_timeout = SettingValidator.timeout!(:open_timeout, open_timeout)
        @read_timeout = SettingValidator.timeout!(:read_timeout, read_timeout)
        @write_timeout = SettingValidator.timeout!(:write_timeout, write_timeout)
        @keep_alive_timeout = SettingValidator.finite_seconds!(:keep_alive_timeout, keep_alive_timeout)
        @debug_output = debug_output
        @pool = ConnectionPool.new
        initialize_proxy(proxy_url)
      end

      # Summarize the connection for the console without revealing proxy credentials
      #
      # @api private
      # @return [String] the class name, proxy URL, and timeouts
      # @example Inspect a connection
      #   connection.inspect # => #<X::Core::Connection proxy_url="http://proxy.example.com:8080" open_timeout=10 ...>
      def inspect
        "#<#{self.class} proxy_url=#{redacted_proxy_url.inspect} open_timeout=#{open_timeout} " \
          "read_timeout=#{read_timeout} write_timeout=#{write_timeout}>"
      end

      # Perform an HTTP request
      #
      # Internal to x-core: Client, its redirects, and token requests send their requests with it, so that it can change
      # within 1.x, as the Net::HTTP requests it takes may.
      #
      # The body of the response is tagged UTF-8, the encoding of the JSON the API sends, rather than the binary that
      # Net::HTTP reads it as, so that it can be searched and joined with other Strings. A body that is not valid
      # UTF-8, such as the page of a proxy in another encoding, keeps its bytes, and valid_encoding? tells it apart.
      #
      # @api private
      # @param request [Net::HTTPRequest] the HTTP request to perform
      # @return [Net::HTTPResponse] the HTTP response, whose body is tagged UTF-8
      # @raise [NetworkError] if a network error occurs
      # @example Perform a request
      #   response = connection.perform(request: request)
      def perform(request:)
        uri = request.uri
        hostname, port = host_and_port(uri)
        use_ssl = uri.scheme.eql?("https")
        send_request(request, [use_ssl, hostname, port], -> { open_http_client(uri, use_ssl) })
      rescue *NETWORK_ERRORS => e
        raise NetworkError.new("Network error: #{e}", **RequestContext.of(request))
      end

      # Perform a streaming HTTP request
      #
      # Internal to x-core: StreamingClient opens its streams with it.
      #
      # The connection is opened for this request and closed once the block returns, rather than taken from the
      # connections kept open and given back, since a stream holds its connection for as long as it reads.
      #
      # An error the block raises, which StreamParser tags as a CallbackError, is raised tagged, rather than reported
      # as a network error: the callbacks of a stream run inside the request that reads it, and the errors a socket
      # raises are the ones a stream reconnects after. The ReconnectHandler of the stream raises it as it was, once it no longer reconnects.
      #
      # The body is not tagged UTF-8 here, as the body of {#perform} is: Net::HTTP tags a body it reads whole, and
      # raises for one it passes to a block a chunk at a time, as a stream is read. StreamParser tags each line of
      # a stream, and the body of a stream that failed, which it reads whole.
      #
      # @api private
      # @param request [Net::HTTPRequest] the HTTP request to perform
      # @yield [Net::HTTPResponse] the HTTP response for streaming
      # @return [void]
      # @raise [NetworkError] if a network error occurs
      # @raise [CallbackError] if a callback of the stream raises
      # @example Perform a streaming request
      #   connection.perform_stream(request: request) { |response| response.read_body { |chunk| } }
      def perform_stream(request:, &)
        http_client = build_http_client(request.uri)
        http_client.use_ssl = request.uri.scheme.eql?("https")
        http_client.request(request, &)
      rescue *NETWORK_ERRORS => e
        raise NetworkError.new("Network error: #{e}", **RequestContext.of(request))
      end

      # Close the connections kept open between requests
      #
      # A later request opens a connection again. Nothing else closes them: the sockets of a connection that is
      # dropped rather than closed are shut as the garbage collector reclaims them, at a time the process does not
      # choose and without the shutdown this performs.
      #
      # @api private
      # @return [void]
      # @example Close the connections before a long pause
      #   connection.close
      def close
        @pool.clear
      end

      # Take connections from the pool of another connection that opens them alike
      #
      # Internal to x-core: Client#with gives a copy the connections of the client it was copied from with it. The
      # two then take their connections from one pool, and close them together, so a copy made for each request opens
      # none of its own. A connection whose timeouts, keep-alive timeout, debug output, or proxy differ keeps a pool
      # of its own, since a connection is opened under those.
      #
      # @api private
      # @param other [Connection] the connection whose pool to share
      # @return [void]
      # @example Share the connections of another connection
      #   connection.share_pool_of(other)
      def share_pool_of(other)
        @pool = other.__send__(:pool) if SETTINGS.all? { |name| __send__(name) == other.__send__(name) }
      end

      private

      # The connections kept open between requests
      # @api private
      # @return [ConnectionPool] the pool
      attr_reader :pool

      # The host and port to connect to for a URI
      #
      # The URI of a request is an HTTP or HTTPS URL, since Net::HTTP builds a request from no other, so it names both.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @return [Array(String, Integer)] the host and the port to connect to
      def host_and_port(uri)
        hostname = uri.hostname #: String
        port = uri.port #: Integer
        [hostname, port]
      end

      # Open an HTTP client for requests read whole, which tags each body UTF-8
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @param use_ssl [Boolean] whether to connect over TLS
      # @return [Net::HTTP] the HTTP client
      def open_http_client(uri, use_ssl)
        build_http_client(uri).tap do |http_client|
          http_client.use_ssl = use_ssl
          http_client.response_body_encoding = Encoding::UTF_8
        end
      end

      # Build an HTTP client for the host of a URI
      #
      # The client connects to an HTTPS proxy over TLS. A client that reaches its host directly is given no proxy to
      # resolve, rather than the :ENV of Net::HTTP, which reads http_proxy for a request of any scheme: the proxy of a
      # request is resolved from the scheme of its own URI, by ConnectionProxy.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @return [Net::HTTP] the HTTP client
      def build_http_client(uri)
        host, port = host_and_port(uri)
        proxy = proxy_for(uri)
        http_client = if proxy
          Net::HTTP.new(host, port, proxy.hostname, proxy.port, decode(proxy.user), decode(proxy.password), nil, proxy.instance_of?(URI::HTTPS))
        else
          Net::HTTP.new(host, port, nil)
        end
        configure_http_client(http_client)
      end

      # Configure a new HTTP client with the timeouts and debug output of the connection
      #
      # The settings of a connection never change, so they are applied as each client is opened, rather than before
      # each request one makes.
      #
      # Net::HTTP sends a GET, PUT, or DELETE request again by itself after a timeout or a dropped connection, with the
      # same OAuth 1.0a nonce and signature, which the API may bill twice, so its retries are turned off: a request
      # that fails raises NetworkError, and the caller decides whether to send it again.
      #
      # Net::HTTP keeps a connection for two seconds by default, which reuses it within a burst of requests alone, so
      # it keeps one for keep_alive_timeout instead.
      #
      # @api private
      # @param http_client [Net::HTTP] the HTTP client to configure
      # @return [Net::HTTP] the configured HTTP client
      def configure_http_client(http_client)
        http_client.tap do |c|
          c.open_timeout = open_timeout
          c.read_timeout = read_timeout
          c.write_timeout = write_timeout
          c.max_retries = 0
          c.keep_alive_timeout = keep_alive_timeout
          c.set_debug_output(debug_output)
        end
      end
    end
    private_constant :Connection
  end
end
