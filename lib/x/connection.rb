require "net/http"
require_relative "errors/network_error"
require_relative "errors/errors"

module X
  # Sends HTTP requests
  class Connection
    include Errors

    def self.send_request(base_url, read_timeout, request)
      url = URI(base_url)
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = url.scheme == "https"
      http.read_timeout = read_timeout
      http.request(request)
    rescue *NETWORK_ERRORS => e
      raise NetworkError, "Network error: #{e.message}"
    end
  end
end
