# frozen_string_literal: true

require_relative "errors/unsupported_operation"

module X
  module Core
    # Refuses Marshal for what holds credentials, included into a client, a streaming client, an authenticator, and
    # an authorization
    #
    # Marshal would write the credentials such an object holds, in the clear, wherever what it writes is kept, such
    # as a cache, where a client in a Hash that is cached would carry them without a word. Where Marshal would not
    # raise TypeError, for a lock the object holds, it would write them silently, so each refuses alike.
    #
    # Internal to x-core: the method it gives these classes, marshal_dump, is public API, but the module is only how
    # it is shared, and which classes include it can change within 1.x.
    #
    # @api private
    module CredentialHolder
      # The message of the error raised for Marshal, which names the class refused
      MARSHAL_MESSAGE = "%s holds credentials, which Marshal would write in the clear wherever it is kept; keep the " \
        "credentials in a secret store, and the X::OAuth2Tokens on_token_refresh is passed, and build it again from them"
      private_constant :MARSHAL_MESSAGE

      # Refuse to be written with Marshal, which would write the credentials
      #
      # @api public
      # @return [void]
      # @raise [UnsupportedOperation] always
      # @example Store the tokens a refresh issued, rather than the client
      #   X::Client.new(**credentials, on_token_refresh: ->(tokens) { store.save(**tokens.to_h) })
      def marshal_dump = raise(UnsupportedOperation, format(MARSHAL_MESSAGE, self.class))
    end
  end
end
