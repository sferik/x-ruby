require "uri"

module X
  module Core
    # The proxy of a connection: its URL, and the host, port, user, and password parsed from it, included into
    # Connection
    #
    # A connection given no proxy URL takes the proxy the environment names for each request, as most HTTP clients
    # do. Net::HTTP reads http_proxy alone, whatever the scheme of the request, which would leave the HTTPS requests
    # these gems make unproxied for anyone who sets https_proxy, and proxied through whatever http_proxy names for
    # anyone who sets that instead. So the proxy of a request is resolved here, from the scheme of its own URI, and
    # passed to Net::HTTP, which is given no proxy of its own to resolve.
    #
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

      # The host of the proxy, without the brackets of an IPv6 literal
      #
      # @api public
      # @return [String, nil] the proxy host, or nil without a proxy
      # @example Get the proxy host
      #   connection.proxy_host
      def proxy_host = proxy_uri&.hostname

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
      def proxy_user = decode(proxy_uri&.user)

      # The password of the proxy, decoded from the proxy URL
      #
      # @api public
      # @return [String, nil] the proxy password
      # @example Get the proxy password
      #   connection.proxy_pass
      def proxy_pass = decode(proxy_uri&.password)

      # Set the proxy URL for requests
      #
      # A user and password in the URL may be percent-encoded, and are decoded for the proxy. An invalid URL leaves the
      # proxy as it was, and its message leaves out the user and password.
      #
      # A connection whose proxy URL is nil proxies a request through whatever the environment names for the scheme of
      # its URI, in https_proxy or http_proxy, and sends a request to a host that no_proxy names without a proxy. Set
      # no_proxy to reach every host directly from a process whose environment names a proxy.
      #
      # @api public
      # @param proxy_url [String, URI::Generic, nil] the proxy URL, or nil to take the proxy from the environment
      # @return [void]
      # @raise [ArgumentError] if the proxy URL is invalid
      # @example Set the proxy URL
      #   connection.proxy_url = "http://proxy.example.com:8080"
      # @example Take the proxy from the environment
      #   connection.proxy_url = nil
      def proxy_url=(proxy_url)
        proxy_uri = proxy_url&.then { |url| parse_proxy_url(url) }
        @proxy_url = proxy_url
        @proxy_uri = proxy_uri
        @pool.clear
      end

      private

      # The proxy of a request, the one given or the one the environment names
      #
      # The proxy the connection was given stands for every request. Otherwise the URI of the request is asked for
      # the proxy of its own scheme, and a relative URI, which names no host for no_proxy to be matched against,
      # takes none.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @return [URI::Generic, nil] the proxy of the request, or nil to reach the host directly
      def proxy_for(uri) = proxy_uri || (uri.find_proxy if uri.absolute?)

      # A percent-encoded component of a proxy URL, decoded
      #
      # @api private
      # @param component [String, nil] the component, or nil for none
      # @return [String, nil] the decoded component, or nil for none
      def decode(component) = component&.then { |value| URI.decode_uri_component(value) }

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
end
