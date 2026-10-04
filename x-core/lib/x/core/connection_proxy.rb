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
    # environment names a proxy. A proxy of the environment that cannot be parsed, or that is not an HTTP or HTTPS
    # URL that names a host, such as proxy.example.com:8080, which has no scheme, is refused as a proxy URL given is,
    # with an ArgumentError that names the variables it is read from and leaves out its value, which can hold a
    # password, though by the request that reads it, since the environment is read for each request that opens a
    # connection, rather than where the client is built. A variable that is empty names no proxy, as it names none
    # to Ruby.
    #
    # Most HTTP clients take the proxy the environment names, and Net::HTTP reads http_proxy alone, whatever the scheme of the request, which would leave the HTTPS requests
    # these gems make unproxied for anyone who sets https_proxy, and proxied through whatever http_proxy names for
    # anyone who sets that instead. So the proxy of a request is resolved here, from the scheme of its own URI, and
    # passed to Net::HTTP, which is given no proxy of its own to resolve.
    #
    # @api private
    module ConnectionProxy
      # The message of the error an HTTPS request raises for a proxy of the environment that is no proxy URL, which
      # names the variables URI::Generic#find_proxy reads for one, in the order it reads them, and leaves out the value
      INVALID_HTTPS_PROXY = "Invalid proxy URL in the environment, in https_proxy or HTTPS_PROXY"
      # The message of the error an HTTP request raises for a proxy of the environment that is no proxy URL, which
      # names the variables URI::Generic#find_proxy reads for one, and leaves out the value: http_proxy, and else
      # HTTP_PROXY, or, in a CGI process, which REQUEST_METHOD is set in, CGI_HTTP_PROXY in place of HTTP_PROXY
      INVALID_HTTP_PROXY = "Invalid proxy URL in the environment, in http_proxy, HTTP_PROXY, or CGI_HTTP_PROXY"
      private_constant :INVALID_HTTPS_PROXY, :INVALID_HTTP_PROXY

      # Raised for a proxy of the environment that cannot be parsed, or is not an HTTP or HTTPS URL that names a host,
      # inside a request, which raises an ArgumentError for it in turn, rather than the NetworkError it raises for an
      # ArgumentError of Net::HTTP
      #
      # @api private
      class InvalidEnvironmentProxy < StandardError; end
      private_constant :InvalidEnvironmentProxy

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
        @proxy_url = @proxy_uri&.then { |uri| String(uri) }
      end

      # The proxy of a request, the one given or the one the environment names
      #
      # The proxy the connection was given stands for every request. Otherwise the URI of the request is asked for
      # the proxy of its own scheme, which is held to what a proxy URL given is: URI::Generic#find_proxy parses a
      # value without a scheme, such as proxy.example.com:8080, into a URI that names no host, which Net::HTTP would
      # take for no proxy at all, and send the request around the proxy its environment names. A variable that is
      # empty, and a host that no_proxy names, have no proxy to check. The error of a proxy of the environment that
      # cannot be parsed has no cause, since the message of the URI::InvalidURIError holds the value of the variable
      # whole, with the password a proxy URL can hold.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request
      # @return [URI::Generic, nil] the proxy of the request, or nil to reach the host directly
      # @raise [InvalidEnvironmentProxy] if the proxy the environment names cannot be parsed, or is not an HTTP or
      #   HTTPS URL that names a host
      def proxy_for(uri)
        proxy_uri || uri.find_proxy&.tap { |proxy| raise InvalidEnvironmentProxy unless proxy_server?(proxy) }
      rescue URI::InvalidURIError
        raise InvalidEnvironmentProxy, cause: nil
      end

      # The error a request raises for a proxy of the environment that is no proxy URL
      #
      # The variable the proxy was read from is not looked up again, which would repeat the lookup of
      # URI::Generic#find_proxy, so the message names each variable that is read for the scheme of the request, in
      # either case, and is true whichever of them was set.
      #
      # @api private
      # @param uri [URI::Generic] the URI of the request, whose scheme names the variables the proxy was read from
      # @return [ArgumentError] the error, whose message names the variables and leaves out the value
      def environment_proxy_error(uri) = ArgumentError.new(uri.scheme.eql?("https") ? INVALID_HTTPS_PROXY : INVALID_HTTP_PROXY)

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

      # Parse a proxy URL, which must be an HTTP or HTTPS URL that names a host
      #
      # A URL that names no host, such as http:proxy:8080, is refused, since Net::HTTP would take its missing host for
      # no proxy at all and send each request around the proxy. The URL is parsed anew, so that a URI the caller
      # changes later does not change the proxy.
      #
      # @api private
      # @param proxy_url [String, URI::Generic] the proxy URL
      # @return [URI::HTTP] the parsed proxy URL
      # @raise [ArgumentError] if the proxy URL is invalid
      def parse_proxy_url(proxy_url)
        proxy_uri = URI(String(proxy_url))
        raise ArgumentError, "Invalid proxy URL: #{redact(proxy_url)}" unless proxy_server?(proxy_uri)

        proxy_uri
      rescue URI::InvalidURIError
        raise ArgumentError, "Invalid proxy URL: #{redact(proxy_url)}", cause: nil
      end

      # Check whether a URI names a proxy, as an HTTP or HTTPS URL with a host does
      #
      # A proxy URL given and the proxy of the environment are held to it alike. A user, a password, a port, and a
      # path are each allowed, and the path is not read.
      #
      # @api private
      # @param uri [URI::Generic] the parsed proxy URL
      # @return [Boolean] true if the URI is an HTTP or HTTPS URL that names a host
      def proxy_server?(uri) = uri.is_a?(URI::HTTP) && !uri.host.to_s.empty?

      # A proxy URL without its user and password
      #
      # A password written into a URL unescaped can hold any character, an @ or a / among them, so everything
      # between the scheme and the last @ is left out, and everything before the last @ of a URL without a scheme.
      #
      # @api private
      # @param proxy_url [String, URI::Generic] the proxy URL
      # @return [String] the URL, without the user and password
      def redact(proxy_url) = String(proxy_url).sub(%r{([^/]*//)?.*@}m, "\\1")
    end
    private_constant :ConnectionProxy
  end
end
