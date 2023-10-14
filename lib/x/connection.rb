require "forwardable"
require "net/http"
require "openssl"
require "uri"
require_relative "errors/network_error"

module X
  # Sends HTTP requests
  class Connection
    extend Forwardable

    DEFAULT_HOST = "api.twitter.com".freeze
    DEFAULT_PORT = 443
    DEFAULT_OPEN_TIMEOUT = 60 # seconds
    DEFAULT_READ_TIMEOUT = 60 # seconds
    DEFAULT_WRITE_TIMEOUT = 60 # seconds
    NETWORK_ERRORS = [
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Net::OpenTimeout,
      Net::ReadTimeout,
      OpenSSL::SSL::SSLError
    ].freeze

    attr_accessor :open_timeout, :read_timeout, :write_timeout, :debug_output
    attr_reader :proxy_uri

    def_delegator :proxy_uri, :host, :proxy_host
    def_delegator :proxy_uri, :port, :proxy_port
    def_delegator :proxy_uri, :user, :proxy_user
    def_delegator :proxy_uri, :password, :proxy_pass

    def initialize(open_timeout: DEFAULT_OPEN_TIMEOUT, read_timeout: DEFAULT_READ_TIMEOUT,
      write_timeout: DEFAULT_WRITE_TIMEOUT, proxy_url: nil, debug_output: nil)
      self.proxy_uri = proxy_url unless proxy_url.nil?
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout
      @debug_output = debug_output
    end

    def send_request(request)
      host = request.uri.host || DEFAULT_HOST
      port = request.uri.port || DEFAULT_PORT
      http_client = build_http_client(host, port)
      http_client.use_ssl = request.uri.scheme == "https"
      response = http_client.request(request)
    rescue *NETWORK_ERRORS => e
      raise NetworkError.new("Network error: #{e.message}", response: response)
    end

    def proxy_uri=(proxy_url)
      proxy_uri = URI(proxy_url)
      raise ArgumentError, "Invalid proxy URL" unless proxy_uri.is_a?(URI::HTTPS) || proxy_uri.is_a?(URI::HTTP)

      @proxy_uri = proxy_uri
    end

    private

    def build_http_client(host = DEFAULT_HOST, port = DEFAULT_PORT)
      http_client = if defined?(@proxy_uri)
        Net::HTTP.new(host, port, proxy_host, proxy_port, proxy_user, proxy_pass)
      else
        Net::HTTP.new(host, port)
      end
      configure_http_client(http_client)
    end

    def configure_http_client(http_client)
      http_client.open_timeout = open_timeout
      http_client.read_timeout = read_timeout
      http_client.write_timeout = write_timeout
      http_client.set_debug_output(debug_output) if debug_output
      http_client
    end
  end
end
