# frozen_string_literal: true

require "net/http"
require "openssl"
require "uri"
require "zlib"
require_relative "connection_pool"
require_relative "connection_proxy"
require_relative "connection_request"
require_relative "proxy_setting"
require_relative "errors/network_error"
require_relative "errors/stream_callback_error"

module X
  # Manages HTTP connections to the X API
  #
  # Requests keep their connections open for the next request to the same host, which saves opening a TCP and
  # TLS connection each time. A stream opens a connection of its own, which it holds for as long as it reads.
  #
  # A connection keeps the settings it was built with for as long as it lives, as {Client} does, so a request never
  # opens a connection under a setting another thread is halfway through changing. Build another connection to
  # reach the API differently.
  #
  # @api public
  class Connection
    include Core::ConnectionProxy
    include Core::ConnectionRequest
    include Core::ProxySetting

    # Default host for the X API
    DEFAULT_HOST = "api.x.com"
    private_constant :DEFAULT_HOST
    # Default port for HTTPS connections
    DEFAULT_PORT = 443
    private_constant :DEFAULT_PORT
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
    # The timeout for opening connections in seconds
    # @api public
    # @return [Integer, Float] the timeout for opening connections in seconds
    # @example Get the open timeout
    #   connection.open_timeout # => 10
    attr_reader :open_timeout

    # The timeout for reading responses in seconds
    # @api public
    # @return [Integer, Float] the timeout for reading responses in seconds
    # @example Get the read timeout
    #   connection.read_timeout # => 60
    attr_reader :read_timeout

    # The timeout for writing requests in seconds
    # @api public
    # @return [Integer, Float] the timeout for writing requests in seconds
    # @example Get the write timeout
    #   connection.write_timeout # => 60
    attr_reader :write_timeout

    # The IO object for debug output
    # @api public
    # @return [IO, nil] the IO object for debug output, or nil for none
    # @example Get the debug output
    #   connection.debug_output
    attr_reader :debug_output

    # The time to keep a connection open for the next request, in seconds
    # @api public
    # @return [Integer, Float] the time in seconds
    # @example Get the keep-alive timeout
    #   connection.keep_alive_timeout # => 30
    attr_reader :keep_alive_timeout

    # Initialize a new connection
    #
    # @api public
    # @param open_timeout [Integer, Float] the timeout for opening connections in seconds
    # @param read_timeout [Integer, Float] the timeout for reading responses in seconds
    # @param write_timeout [Integer, Float] the timeout for writing requests in seconds
    # @param keep_alive_timeout [Integer, Float] the time to keep a connection open for the next request to the same
    #   host, in seconds, which a proxy that closes idle connections sooner than X does may need lowered
    # @param debug_output [IO, nil] the IO object for debug output
    # @param proxy_url [String, URI::Generic, nil] the proxy URL for requests
    # @return [Connection] a new connection instance
    # @example Create a connection with default settings
    #   connection = X::Connection.new
    # @example Create a connection with custom timeouts
    #   connection = X::Connection.new(open_timeout: 30, read_timeout: 30)
    def initialize(open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT,
      write_timeout: DEFAULT_WRITE_TIMEOUT, keep_alive_timeout: DEFAULT_KEEP_ALIVE_TIMEOUT, debug_output: nil, proxy_url: nil)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout
      @keep_alive_timeout = keep_alive_timeout
      @debug_output = debug_output
      @pool = Core::ConnectionPool.new
      initialize_proxy(proxy_url)
    end

    # Summarize the connection for the console without revealing proxy credentials
    #
    # @api public
    # @return [String] the class name, proxy URL, and timeouts
    # @example Inspect a connection
    #   connection.inspect # => #<X::Connection proxy_url="http://proxy.example.com:8080" open_timeout=10 ...>
    def inspect
      "#<#{self.class} proxy_url=#{redacted_proxy_url.inspect} open_timeout=#{open_timeout} " \
        "read_timeout=#{read_timeout} write_timeout=#{write_timeout}>"
    end

    # Perform an HTTP request
    #
    # Internal to x-core: Client, its redirects, and token requests send their requests with it, so that it can change
    # within 1.x, as the Net::HTTP requests it takes may.
    #
    # @api private
    # @param request [Net::HTTPRequest] the HTTP request to perform
    # @return [Net::HTTPResponse] the HTTP response
    # @raise [NetworkError] if a network error occurs
    # @example Perform a request
    #   response = connection.perform(request: request)
    def perform(request:)
      uri = request.uri
      hostname, port = host_and_port(uri)
      use_ssl = uri.scheme.eql?("https")
      open = -> { build_http_client(uri).tap { |http_client| http_client.use_ssl = use_ssl } }
      send_request(request, [use_ssl, hostname, port], open)
    rescue *NETWORK_ERRORS => e
      raise NetworkError.new("Network error: #{e}", request:)
    end

    # Perform a streaming HTTP request
    #
    # Internal to x-core: StreamingClient opens its streams with it.
    #
    # The connection is opened for this request and closed once the block returns, rather than taken from the
    # connections kept open and given back, since a stream holds its connection for as long as it reads.
    #
    # An error the block raises, which StreamParser tags as a StreamCallbackError, is raised as it was, rather than
    # reported as a network error: the callbacks of a stream run inside the request that reads it, and the errors a
    # socket raises are the ones a stream reconnects after.
    #
    # @api private
    # @param request [Net::HTTPRequest] the HTTP request to perform
    # @yield [Net::HTTPResponse] the HTTP response for streaming
    # @return [void]
    # @raise [NetworkError] if a network error occurs
    # @example Perform a streaming request
    #   connection.perform_stream(request: request) { |response| response.read_body { |chunk| } }
    def perform_stream(request:, &)
      http_client = build_http_client(request.uri)
      http_client.use_ssl = request.uri.scheme.eql?("https")
      http_client.request(request, &)
    rescue Core::StreamCallbackError => e
      raise e.error
    rescue *NETWORK_ERRORS => e
      raise NetworkError.new("Network error: #{e}", request:)
    end

    # Close the connections kept open between requests
    #
    # A later request opens a connection again. Nothing else closes them: the sockets of a connection that is
    # dropped rather than closed are shut as the garbage collector reclaims them, at a time the process does not
    # choose and without the shutdown this performs.
    #
    # @api public
    # @return [void]
    # @example Close the connections before a long pause
    #   connection.close
    def close
      @pool.clear
    end

    private

    # The host and port to connect to for a URI
    #
    # A URI that names neither, such as a relative one, is reached at the host and port of the API.
    #
    # @api private
    # @param uri [URI::Generic] the URI of the request
    # @return [Array(String, Integer)] the host and the port to connect to
    def host_and_port(uri) = [uri.hostname || DEFAULT_HOST, uri.port || DEFAULT_PORT]

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
end
