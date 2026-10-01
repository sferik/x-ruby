# frozen_string_literal: true

module X
  module Core
    # Refuses Marshal and YAML for what holds credentials, included into a client and its internals, an
    # authenticator, and an authorization
    #
    # Marshal and YAML would write the credentials such an object holds, in the clear, wherever what they write is
    # kept, such as a cache, where a client in a Hash that is cached would carry them without a word, or the arguments
    # of a job a queue writes as YAML. Where Marshal would not raise TypeError, for a lock the object holds, it would
    # write them silently, and YAML writes every instance variable, a lock or not, so each refuses alike, with the
    # TypeError Marshal raises for what it cannot write, such as a Proc, so that code that rescues it around
    # Marshal.dump, as a cache or a deep copy does, rescues this too.
    #
    # Internal to x-core: the methods it gives these classes, marshal_dump and encode_with, are public API, but the
    # module is only how they are shared, and which classes include it can change within 1.x.
    #
    # @api private
    module CredentialHolder
      # The message of the error raised for Marshal or YAML, which names the class refused and what refused it
      REFUSAL_MESSAGE = "%s holds credentials, which %s would write in the clear wherever it is kept; keep the " \
        "credentials in a secret store, and the X::OAuth2Tokens save_tokens is passed, and build it again from them"
      private_constant :REFUSAL_MESSAGE

      # Refuse to be written with Marshal, which would write the credentials
      #
      # @api public
      # @return [void]
      # @raise [TypeError] always
      # @example Store the tokens a refresh issued, rather than the client
      #   X::Client.new(**credentials, save_tokens: ->(tokens) { store.save(**tokens.to_h) })
      def marshal_dump = raise(TypeError, format(REFUSAL_MESSAGE, self.class, "Marshal"))

      # Refuse to be written as YAML, which would write the credentials
      #
      # YAML reads no marshal_dump, and writes every instance variable of an object that does not say how it is
      # written, credentials and all, so it is refused as Marshal is.
      #
      # @api public
      # @param _coder [Psych::Coder] the coder YAML would write the object with
      # @return [void]
      # @raise [TypeError] always
      # @example Enqueue the identifier of a user, rather than a client, for a job its queue writes as YAML
      #   PostJob.perform_later(user_id: client.current_user_id)
      def encode_with(_coder) = raise(TypeError, format(REFUSAL_MESSAGE, self.class, "YAML"))
    end
    private_constant :CredentialHolder
  end
end
