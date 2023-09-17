require "forwardable"
require "net/http"
require "uri"
require_relative "errors/network_error"

module X
  # Sends HTTP requests
  class Connection
    extend Forwardable

    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze
    DEFAULT_HOST = "https://api.twitter.com".freeze
    DEFAULT_PORT = 443
    DEFAULT_OPEN_TIMEOUT = 60 # seconds
    DEFAULT_READ_TIMEOUT = 60 # seconds
    DEFAULT_WRITE_TIMEOUT = 60 # seconds
    NETWORK_ERRORS = [
      Errno::ECONNREFUSED,
      Net::OpenTimeout,
      Net::ReadTimeout
    ].freeze

    attr_reader :base_uri, :http_client

    def_delegators :@http_client, :open_timeout, :read_timeout, :write_timeout
    def_delegators :@http_client, :open_timeout=, :read_timeout=, :write_timeout=
    def_delegator :@http_client, :set_debug_output, :debug_output=

    def initialize(base_url: DEFAULT_BASE_URL, open_timeout: DEFAULT_OPEN_TIMEOUT,
      read_timeout: DEFAULT_READ_TIMEOUT, write_timeout: DEFAULT_WRITE_TIMEOUT, debug_output: nil)
      self.base_uri = base_url
      apply_http_client_settings(
        open_timeout: open_timeout,
        read_timeout: read_timeout,
        write_timeout: write_timeout,
        debug_output: debug_output
      )
    end

    def send_request(request)
      @http_client.request(request)
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Network error: #{e.message}"
    end

    def base_uri=(base_url)
      base_uri = URI(base_url)
      raise ArgumentError, "Invalid base URL" unless base_uri.is_a?(URI::HTTPS) || base_uri.is_a?(URI::HTTP)

      @base_uri = base_uri
      update_http_client_settings
    end

    def debug_output
      @http_client.instance_variable_get(:@debug_output)
    end

    private

    def apply_http_client_settings(open_timeout:, read_timeout:, write_timeout:, debug_output:)
      @http_client.open_timeout = open_timeout
      @http_client.read_timeout = read_timeout
      @http_client.write_timeout = write_timeout
      @http_client.set_debug_output(debug_output) if debug_output
    end

    def current_http_client_settings
      {
        open_timeout: @http_client.open_timeout,
        read_timeout: @http_client.read_timeout,
        write_timeout: @http_client.write_timeout,
        debug_output: debug_output
      }
    end

    def update_http_client_settings
      conditionally_apply_http_client_settings do
        host = @base_uri.host || DEFAULT_HOST
        port = @base_uri.port || DEFAULT_PORT
        @http_client = Net::HTTP.new(host, port)
        @http_client.use_ssl = @base_uri.scheme == "https"
      end
    end

    def conditionally_apply_http_client_settings
      if @http_client
        settings = current_http_client_settings
        yield
        apply_http_client_settings(**settings)
      else
        yield
      end
    end
  end
end
