require "forwardable"
require "net/http"
require "openssl"
require "uri"
require_relative "connection_pool"
require_relative "errors/network_error"

module X
  # Manages HTTP connections to the X API
  #
  # Requests keep their connections open for the next request to the same host, which saves opening a TCP and
  # TLS connection each time. A stream opens a connection of its own, which it holds for as long as it reads.
  #
  # @api public
  class Connection
    extend Forwardable

    # Default host for the X API
    DEFAULT_HOST = "api.x.com".freeze
    # Default port for HTTPS connections
    DEFAULT_PORT = 443
    # Default timeout for opening connections in seconds
    DEFAULT_OPEN_TIMEOUT = 60 # seconds
    # Default timeout for reading responses in seconds
    DEFAULT_READ_TIMEOUT = 60 # seconds
    # Default timeout for writing requests in seconds
    DEFAULT_WRITE_TIMEOUT = 60 # seconds
    # Network errors that should be wrapped in NetworkError
    NETWORK_ERRORS = [
      EOFError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      Errno::ETIMEDOUT,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::WriteTimeout,
      OpenSSL::SSL::SSLError,
      SocketError
    ].freeze

    # The timeout for opening connections in seconds
    # @api public
    # @return [Integer] the timeout for opening connections in seconds
    # @example Get or set the open timeout
    #   connection.open_timeout = 30
    attr_accessor :open_timeout

    # The timeout for reading responses in seconds
    # @api public
    # @return [Integer] the timeout for reading responses in seconds
    # @example Get or set the read timeout
    #   connection.read_timeout = 30
    attr_accessor :read_timeout

    # The timeout for writing requests in seconds
    # @api public
    # @return [Integer] the timeout for writing requests in seconds
    # @example Get or set the write timeout
    #   connection.write_timeout = 30
    attr_accessor :write_timeout

    # The IO object for debug output
    # @api public
    # @return [IO] the IO object for debug output
    # @example Get the debug output
    #   connection.debug_output
    attr_reader :debug_output

    # The proxy URL for requests
    # @api public
    # @return [String, nil] the proxy URL for requests
    # @example Get the proxy URL
    #   connection.proxy_url
    attr_reader :proxy_url

    # The parsed proxy URI
    # @api public
    # @return [URI, nil] the parsed proxy URI
    # @example Get the proxy URI
    #   connection.proxy_uri
    attr_reader :proxy_uri

    def_delegator :proxy_uri, :host, :proxy_host
    def_delegator :proxy_uri, :port, :proxy_port
    def_delegator :proxy_uri, :user, :proxy_user
    def_delegator :proxy_uri, :password, :proxy_pass

    # Initialize a new connection
    #
    # @api public
    # @param open_timeout [Integer] the timeout for opening connections in seconds
    # @param read_timeout [Integer] the timeout for reading responses in seconds
    # @param write_timeout [Integer] the timeout for writing requests in seconds
    # @param debug_output [IO] the IO object for debug output
    # @param proxy_url [String, nil] the proxy URL for requests
    # @return [Connection] a new connection instance
    # @example Create a connection with default settings
    #   connection = X::Connection.new
    # @example Create a connection with custom timeouts
    #   connection = X::Connection.new(open_timeout: 30, read_timeout: 30)
    def initialize(open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT,
      write_timeout: DEFAULT_WRITE_TIMEOUT, debug_output: nil, proxy_url: nil)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout
      @debug_output = debug_output
      @pool = ConnectionPool.new
      self.proxy_url = proxy_url unless proxy_url.nil?
    end

    # Perform an HTTP request
    #
    # @api public
    # @param request [Net::HTTPRequest] the HTTP request to perform
    # @return [Net::HTTPResponse] the HTTP response
    # @raise [NetworkError] if a network error occurs
    # @example Perform a request
    #   response = connection.perform(request: request)
    def perform(request:)
      uri = request.uri
      host = uri.host || DEFAULT_HOST
      port = uri.port || DEFAULT_PORT
      use_ssl = uri.scheme.eql?("https")
      open = -> { build_http_client(host, port).tap { |http_client| http_client.use_ssl = use_ssl } }
      @pool.with([use_ssl, host, port], open) { |http_client| configure_timeouts(http_client).request(request) }
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Network error: #{e}"
    end

    # Perform a streaming HTTP request
    #
    # @api public
    # @param request [Net::HTTPRequest] the HTTP request to perform
    # @yield [Net::HTTPResponse] the HTTP response for streaming
    # @return [void]
    # @raise [NetworkError] if a network error occurs
    # @example Perform a streaming request
    #   connection.perform_stream(request: request) { |response| response.read_body { |chunk| } }
    def perform_stream(request:, &)
      host = request.uri.host || DEFAULT_HOST
      port = request.uri.port || DEFAULT_PORT
      http_client = build_http_client(host, port)
      http_client.use_ssl = request.uri.scheme.eql?("https")
      http_client.request(request, &)
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

    # Set the proxy URL for requests
    #
    # @api public
    # @param proxy_url [String] the proxy URL
    # @return [void]
    # @raise [ArgumentError] if the proxy URL is invalid
    # @example Set the proxy URL
    #   connection.proxy_url = "http://proxy.example.com:8080"
    def proxy_url=(proxy_url)
      @proxy_url = proxy_url
      proxy_uri = URI(proxy_url)
      raise ArgumentError, "Invalid proxy URL: #{proxy_uri}" unless proxy_uri.is_a?(URI::HTTP)

      @proxy_uri = proxy_uri
      @pool.clear
    end

    private

    # Build an HTTP client for the given host and port
    # @api private
    # @param host [String] the host to connect to
    # @param port [Integer] the port to connect to
    # @return [Net::HTTP] the HTTP client
    def build_http_client(host = DEFAULT_HOST, port = DEFAULT_PORT)
      http_client = if proxy_uri
        Net::HTTP.new(host, port, proxy_host, proxy_port, proxy_user, proxy_pass)
      else
        Net::HTTP.new(host, port)
      end
      configure_http_client(http_client)
    end

    # Configure a new HTTP client with timeout settings and debug output
    # @api private
    # @param http_client [Net::HTTP] the HTTP client to configure
    # @return [Net::HTTP] the configured HTTP client
    def configure_http_client(http_client)
      configure_timeouts(http_client).tap { |c| c.set_debug_output(debug_output) }
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
