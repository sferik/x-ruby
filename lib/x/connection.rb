require "forwardable"
require "net/http"
require "uri"
require_relative "errors/errors"
require_relative "errors/network_error"

module X
  # Sends HTTP requests
  class Connection
    extend Forwardable
    include Errors

    DEFAULT_BASE_URL = "https://api.twitter.com/2/".freeze
    DEFAULT_OPEN_TIMEOUT = 60 # seconds
    DEFAULT_READ_TIMEOUT = 60 # seconds
    DEFAULT_WRITE_TIMEOUT = 60 # seconds

    attr_reader :base_uri

    def_delegators :@http_client, :open_timeout, :read_timeout, :write_timeout
    def_delegators :@http_client, :open_timeout=, :read_timeout=, :write_timeout=
    def_delegator :@http_client, :set_debug_output, :debug_output=

    def initialize(base_url: DEFAULT_BASE_URL, open_timeout: DEFAULT_OPEN_TIMEOUT,
      read_timeout: DEFAULT_READ_TIMEOUT, write_timeout: DEFAULT_WRITE_TIMEOUT, debug_output: nil)
      self.base_uri = base_url
      @http_client = Net::HTTP.new(base_uri.host, base_uri.port) if base_uri.host
      @http_client.use_ssl = base_uri.scheme == "https"
      @http_client.open_timeout = open_timeout
      @http_client.read_timeout = read_timeout
      @http_client.write_timeout = write_timeout
      @http_client.set_debug_output(debug_output) if debug_output
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
    end

    def debug_output
      @http_client.instance_variable_get(:@debug_output)
    end
  end
end
