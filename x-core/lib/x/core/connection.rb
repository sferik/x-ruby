require "net/http"
require "openssl"
require "uri"
require "zlib"
require_relative "connection_pool"
require_relative "connection_proxy"
require_relative "errors/network_error"
require_relative "errors/stream_callback_error"

module X
  # Manages HTTP connections to the X API
  #
  # Requests keep their connections open for the next request to the same host, which saves opening a TCP and
  # TLS connection each time. A stream opens a connection of its own, which it holds for as long as it reads.
  #
  # @api public
  class Connection
    include Core::ConnectionProxy

    # Default host for the X API
    DEFAULT_HOST = "api.x.com".freeze
    private_constant :DEFAULT_HOST
    # Default port for HTTPS connections
    DEFAULT_PORT = 443
    private_constant :DEFAULT_PORT
    # Default timeout for opening connections in seconds
    DEFAULT_OPEN_TIMEOUT = 60 # seconds
    # Default timeout for reading responses in seconds
    DEFAULT_READ_TIMEOUT = 60 # seconds
    # Default timeout for writing requests in seconds
    DEFAULT_WRITE_TIMEOUT = 60 # seconds
    # Default time to keep a connection open for the next request to the same host, in seconds; X holds an idle
    # connection open for more than five minutes, so a connection closed within this time was closed by a proxy
    DEFAULT_KEEP_ALIVE_TIMEOUT = 30 # seconds
    # Network errors that should be wrapped in NetworkError
    #
    # IOError covers EOFError, and a read from a socket closed under it. SystemCallError covers every error the
    # operating system reports for a socket, such as a refused, reset, or aborted connection, a network that is down
    # or has no route, or a write refused with EPIPE. Timeout::Error covers the open, read, and write timeouts of
    # Net::HTTP. A connection cut off mid-response can leave Net::HTTP a status line it cannot parse, or a compressed
    # body that Zlib cannot inflate, and a proxy that refuses to open a tunnel, such as with 407 Proxy Authentication
    # Required, raises a Net::ProtocolError.
    NETWORK_ERRORS = [
      IOError,
      Net::HTTPBadResponse,
      Net::ProtocolError,
      OpenSSL::SSL::SSLError,
      SocketError,
      SystemCallError,
      Timeout::Error,
      Zlib::Error
    ].freeze
    private_constant :NETWORK_ERRORS

    # The timeout for opening connections in seconds
    # @api public
    # @return [Integer, Float] the timeout for opening connections in seconds
    # @example Get or set the open timeout
    #   connection.open_timeout = 30
    attr_accessor :open_timeout

    # The timeout for reading responses in seconds
    # @api public
    # @return [Integer, Float] the timeout for reading responses in seconds
    # @example Get or set the read timeout
    #   connection.read_timeout = 30
    attr_accessor :read_timeout

    # The timeout for writing requests in seconds
    # @api public
    # @return [Integer, Float] the timeout for writing requests in seconds
    # @example Get or set the write timeout
    #   connection.write_timeout = 30
    attr_accessor :write_timeout

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
      self.proxy_url = proxy_url
    end

    # Summarize the connection for the console without revealing proxy credentials
    #
    # @api public
    # @return [String] the class name, proxy URL, and timeouts
    # @example Inspect a connection
    #   connection.inspect # => #<X::Connection proxy_url="http://proxy.example.com:8080" open_timeout=60 ...>
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
      hostname = uri.hostname || DEFAULT_HOST
      port = uri.port || DEFAULT_PORT
      use_ssl = uri.scheme.eql?("https")
      open = -> { build_http_client(hostname, port).tap { |http_client| http_client.use_ssl = use_ssl } }
      @pool.with([use_ssl, hostname, port], open) { |http_client| configure_timeouts(http_client).request(request) }
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Network error: #{e}"
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
      hostname = request.uri.hostname || DEFAULT_HOST
      port = request.uri.port || DEFAULT_PORT
      http_client = build_http_client(hostname, port)
      http_client.use_ssl = request.uri.scheme.eql?("https")
      http_client.request(request, &)
    rescue Core::StreamCallbackError => e
      raise e.error
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Network error: #{e}"
    end

    # Set the IO object for debug output, for the connections opened from now on
    #
    # @api public
    # @param debug_output [IO, nil] the IO object for debug output, or nil for none
    # @return [void]
    # @example Set the debug output
    #   connection.debug_output = $stderr
    def debug_output=(debug_output)
      @debug_output = debug_output
      @pool.clear
    end

    # Set the time to keep a connection open, closing the connections kept open
    #
    # A connection that a proxy closed while it was kept open fails the next request with NetworkError, so a client
    # behind a proxy that closes idle connections sooner than X does keeps them for less time.
    #
    # @api public
    # @param keep_alive_timeout [Integer, Float] the time in seconds
    # @return [void]
    # @example Keep a connection open for five seconds
    #   connection.keep_alive_timeout = 5
    def keep_alive_timeout=(keep_alive_timeout)
      @keep_alive_timeout = keep_alive_timeout
      @pool.clear
    end

    # Close the connections kept open between requests
    #
    # A later request opens a connection again. Connections also close when the connection is garbage collected.
    #
    # @api public
    # @return [void]
    # @example Close the connections before a long pause
    #   connection.close
    def close
      @pool.clear
    end

    private

    # Build an HTTP client for the given host and port
    #
    # The client connects to an HTTPS proxy over TLS.
    #
    # @api private
    # @param host [String] the host to connect to
    # @param port [Integer] the port to connect to
    # @return [Net::HTTP] the HTTP client
    def build_http_client(host = DEFAULT_HOST, port = DEFAULT_PORT)
      http_client = if proxy_uri
        Net::HTTP.new(host, port, proxy_host, proxy_port, proxy_user, proxy_pass, nil, proxy_uri.instance_of?(URI::HTTPS))
      else
        Net::HTTP.new(host, port)
      end
      configure_http_client(http_client)
    end

    # Configure a new HTTP client with timeout settings and debug output
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
      configure_timeouts(http_client).tap do |c|
        c.max_retries = 0
        c.keep_alive_timeout = keep_alive_timeout
        c.set_debug_output(debug_output)
      end
    end

    # Apply the current timeouts to an HTTP client, before each request it makes
    # @api private
    # @param http_client [Net::HTTP] the HTTP client to configure
    # @return [Net::HTTP] the configured HTTP client
    def configure_timeouts(http_client)
      http_client.tap do |c|
        c.open_timeout = open_timeout
        c.read_timeout = read_timeout
        c.write_timeout = write_timeout
      end
    end
  end
end
