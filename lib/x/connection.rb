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

    def initialize(base_url:, open_timeout:, read_timeout:, write_timeout:)
      self.base_url = URI(base_url)
      @http_client = Net::HTTP.new(@base_url.host, @base_url.port)
      @http_client.use_ssl = @base_url.scheme == "https"
      @http_client.open_timeout = open_timeout
      @http_client.read_timeout = read_timeout
      @http_client.write_timeout = write_timeout
    end

    def send_request(request:)
      @http_client.request(request)
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Network error: #{e.message}"
    end

    def base_url=(new_base_url)
      uri = URI(new_base_url)
      raise ArgumentError, "Invalid base URL" unless uri.is_a?(URI::HTTPS) || uri.is_a?(URI::HTTP)

      @base_url = uri
    end
  end
end
