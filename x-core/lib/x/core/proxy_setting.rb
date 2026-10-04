# frozen_string_literal: true

module X
  module Core
    # The proxy URL a connection, or the internals of a client, was built with, included into each
    #
    # A proxy URL can hold the user and password of the proxy, so neither reveals it to a caller, as a client reveals
    # none of its secrets. The reader is private, and a copy of a client, which opens its connections with the proxy
    # of the client it copies, calls it on the internals of that client with __send__.
    #
    # @api private
    module ProxySetting
      private

      # The proxy URL, as it was given
      # @api private
      # @return [String, URI::Generic, nil] the proxy URL, or nil to take the proxy the environment names
      def proxy_url = @proxy_url
    end
    private_constant :ProxySetting
  end
end
