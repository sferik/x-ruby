# frozen_string_literal: true

module X
  module Core
    # The proxy URL a connection, a client, or a streaming client was built with, included into each of them
    #
    # A proxy URL can hold the user and password of the proxy, so none of the three reveals it to a caller, as a
    # client reveals none of its secrets. The reader is private, and a streaming client, which builds its connection
    # with the proxy of the client it streams for, calls it with __send__.
    #
    # @api private
    module ProxySetting
      private

      # The proxy URL, as it was given
      # @api private
      # @return [String, URI::Generic, nil] the proxy URL, or nil to take the proxy the environment names
      def proxy_url = @proxy_url
    end
  end
end
