require "uri"

module X
  # The proxy of a connection: its URL, and the host, port, user, and password parsed from it, included into
  # Connection
  # @api private
  module ConnectionProxy
    # The proxy URL for requests
    # @api public
    # @return [String, URI::Generic, nil] the proxy URL for requests, as it was given
    # @example Get the proxy URL
    #   connection.proxy_url
    attr_reader :proxy_url

    # The parsed proxy URI
    # @api public
    # @return [URI, nil] the parsed proxy URI
    # @example Get the proxy URI
    #   connection.proxy_uri
    attr_reader :proxy_uri

    # The host of the proxy
    #
    # @api public
    # @return [String, nil] the proxy host, or nil without a proxy
    # @example Get the proxy host
    #   connection.proxy_host
    def proxy_host = proxy_uri&.host

    # The port of the proxy
    #
    # @api public
    # @return [Integer, nil] the proxy port, or nil without a proxy
    # @example Get the proxy port
    #   connection.proxy_port
    def proxy_port = proxy_uri&.port

    # The user of the proxy, decoded from the proxy URL
    #
    # @api public
    # @return [String, nil] the proxy user
    # @example Get the proxy user
    #   connection.proxy_user
    def proxy_user = proxy_uri&.user&.then { |user| URI.decode_uri_component(user) }

    # The password of the proxy, decoded from the proxy URL
    #
    # @api public
    # @return [String, nil] the proxy password
    # @example Get the proxy password
    #   connection.proxy_pass
    def proxy_pass = proxy_uri&.password&.then { |password| URI.decode_uri_component(password) }

    # Set the proxy URL for requests
    #
    # A user and password in the URL may be percent-encoded, and are decoded for the proxy. An invalid URL leaves the
    # proxy as it was, and its message leaves out the user and password.
    #
    # @api public
    # @param proxy_url [String, URI::Generic, nil] the proxy URL, or nil for none
    # @return [void]
    # @raise [ArgumentError] if the proxy URL is invalid
    # @example Set the proxy URL
    #   connection.proxy_url = "http://proxy.example.com:8080"
    # @example Stop using a proxy
    #   connection.proxy_url = nil
    def proxy_url=(proxy_url)
      proxy_uri = proxy_url&.then { |url| parse_proxy_url(url) }
      @proxy_url = proxy_url
      @proxy_uri = proxy_uri
      @pool.clear
    end

    private

    # The proxy URL without its user and password
    # @api private
    # @return [String, nil] the proxy URL, without its user and password
    def redacted_proxy_url = proxy_url&.then { |url| redact(url) }

    # Parse a proxy URL, which must be an HTTP or HTTPS URL
    # @api private
    # @param proxy_url [String, URI::Generic] the proxy URL
    # @return [URI::HTTP] the parsed proxy URL
    # @raise [ArgumentError] if the proxy URL is invalid
    def parse_proxy_url(proxy_url)
      proxy_uri = URI(proxy_url)
      raise ArgumentError, "Invalid proxy URL: #{redact(proxy_url)}" unless proxy_uri.is_a?(URI::HTTP)

      proxy_uri
    rescue URI::InvalidURIError
      raise ArgumentError, "Invalid proxy URL: #{redact(proxy_url)}"
    end

    # A proxy URL without its user and password
    # @api private
    # @param proxy_url [String, URI::Generic] the proxy URL
    # @return [String] the URL, without the user and password
    def redact(proxy_url) = String(proxy_url).sub(%r{(?<=//)[^/@]*@}, "")
  end
end
