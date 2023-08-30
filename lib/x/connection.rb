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

    attr_reader :base_url

    def_delegators :@http_client, :open_timeout, :read_timeout, :write_timeout
    def_delegators :@http_client, :open_timeout=, :read_timeout=, :write_timeout=
    def_delegator :@http_client, :set_debug_output, :debug_output=

    def initialize(url, open_timeout, read_timeout, write_timeout, debug_output: nil)
      self.base_url = url
      @http_client = Net::HTTP.new(base_url.host, base_url.port) if base_url.host
      @http_client.use_ssl = base_url.scheme == "https"
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

    def base_url=(new_base_url)
      uri = URI(new_base_url)
      raise ArgumentError, "Invalid base URL" unless uri.is_a?(URI::HTTPS) || uri.is_a?(URI::HTTP)

      @base_url = uri
    end

    def debug_output
      @http_client.instance_variable_get(:@debug_output)
    end
  end
end
