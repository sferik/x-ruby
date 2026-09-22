# frozen_string_literal: true

require "uri"
require_relative "authenticator"

module X
  module Core
    # The origin a request is sent to, and the credentials it carries there
    #
    # Credentials are for the origin they were given for: the scheme, host, and port of the base URL of a client.
    # A request to any other origin carries none of them, whether it was a redirect followed there or an endpoint
    # that named a whole URL, since the credentials of the API are no business of another host. What is dropped is
    # the authenticator, which signs the Authorization header of a request, and any Authorization, Cookie, or
    # Proxy-Authorization header of the client or the request itself.
    #
    # Internal to x-core: Client, StreamingClient, and RedirectHandler decide with it what a request carries.
    #
    # @api private
    module Origin
      extend self

      # The headers that carry credentials, which a request to another origin drops
      CREDENTIAL_HEADERS = [Authenticator::AUTHENTICATION_HEADER, "Cookie", "Proxy-Authorization"].freeze

      # The authenticator and headers a request carries to an origin
      #
      # The credentials that would leave the origin they were given for are dropped.
      #
      # @api private
      # @param from [URI::Generic] the URI the credentials were given for, such as the base URL of a client
      # @param to [URI::Generic] the URI the request is sent to
      # @param authenticator [Authenticator] the authenticator of the request
      # @param headers [Hash{String, Symbol => String}] the headers of the request
      # @return [Array(Authenticator, Hash{String, Symbol => String})] the authenticator that signs the request,
      #   and the headers it is sent with
      # @example Keep the credentials of a request to the API
      #   X::Core::Origin.credentials_for(from: URI(client.base_url), to: uri, authenticator:, headers:)
      def credentials_for(from:, to:, authenticator:, headers:)
        return [authenticator, headers] if same?(from, to)

        [Authenticator.new, without_credentials(headers)]
      end

      # Check whether two URIs share a scheme, host, and port
      #
      # @api private
      # @param uri [URI::Generic] the one URI
      # @param other [URI::Generic] the other URI
      # @return [Boolean] true if both have the same origin
      # @example Check whether an endpoint names the host of the base URL
      #   X::Core::Origin.same?(URI(client.base_url), uri)
      def same?(uri, other) = of(uri).eql?(of(other))

      private

      # The scheme, host, and port of a URI, in lowercase
      # @api private
      # @param uri [URI::Generic] the URI
      # @return [Array(String, String, Integer)] the origin
      def of(uri)
        normalized = uri.normalize
        [normalized.scheme, normalized.host, normalized.port]
      end

      # Headers without the ones that carry credentials
      #
      # Authorization, Cookie, and Proxy-Authorization are dropped, whatever their case, whether a String or a Symbol
      # names them.
      #
      # @api private
      # @param headers [Hash{String, Symbol => String}] the headers
      # @return [Hash{String, Symbol => String}] the headers that carry no credentials
      def without_credentials(headers)
        headers.reject { |name, _| CREDENTIAL_HEADERS.any? { |header| name.to_s.casecmp?(header) } }
      end
    end
  end
end
