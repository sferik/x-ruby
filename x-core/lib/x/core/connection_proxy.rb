# frozen_string_literal: true

require "uri"

module X
  module Core
    # The proxy of a connection, parsed from its URL, included into Connection
    #
    # A proxy URL can hold the user and password of the proxy, so a connection reveals neither its URL nor anything
    # parsed from it, and its inspect leaves out the user and password; see {ProxySetting}.
    #
    # A connection given no proxy URL takes the proxy the environment names for each request, and sends a request to
    # a host that no_proxy names without a proxy. Set no_proxy to reach every host directly from a process whose
    # environment names a proxy.
    #
    # Most HTTP clients take the proxy the environment names, and Net::HTTP reads http_proxy alone, whatever the scheme of the request, which would leave the HTTPS requests
    # these gems make unproxied for anyone who sets https_proxy, and proxied through whatever http_proxy names for
    # anyone who sets that instead. So the proxy of a request is resolved here, from the scheme of its own URI, and
    # passed to Net::HTTP, which is given no proxy of its own to resolve.
    #
    # @api private
    module ConnectionProxy
      private

      # The parsed proxy URI
      # @api private
      # @return [URI::Generic, nil] the parsed proxy URI, or nil to take the proxy the environment names
      attr_reader :proxy_uri

      # Read the proxy URL a connection is built with
      #
      # A connection keeps it for as long as it lives, as it keeps every setting. The message of an invalid URL
      # leaves out its user and password.
      #
      # @api private
      # @param proxy_url [String, URI::Generic, nil] the proxy URL, or nil to take the proxy from the environment
      # @return [void]
      # @raise [ArgumentError] if the proxy URL is invalid
      def initialize_proxy(proxy_url)
        @proxy_uri = proxy_url&.then { |url| parse_proxy_url(url) }
        @proxy_url = proxy_url
      end

      # The proxy of a request, the one given or the one the environment names
      #
      # The proxy the connection was given stands for every request. Otherwise the URI of the request is asked for
      # the proxy of its own scheme.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @return [URI::Generic, nil] the proxy of the request, or nil to reach the host directly
      def proxy_for(uri) = proxy_uri || uri.find_proxy

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
