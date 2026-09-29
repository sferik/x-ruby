# frozen_string_literal: true

require_relative "errors/unsupported_marshal_format"

module X
  # The OAuth 2.0 tokens one refresh issued, which on_token_refresh is passed to store
  #
  # It is frozen, and taken while the refresh holds its lock, so it holds the tokens of the refresh it reports,
  # whatever refreshes follow on other threads, where the authenticator holds the tokens of the latest one.
  #
  # @api public
  class OAuth2Tokens
    # The number of the format of the state Marshal writes, which a release that changes the format raises
    MARSHAL_FORMAT = 1
    private_constant :MARSHAL_FORMAT

    # The OAuth 2.0 access token the refresh issued
    # @api public
    # @return [String] the access token
    # @example Get the access token
    #   tokens.access_token
    attr_reader :access_token

    # The OAuth 2.0 refresh token the refresh issued
    #
    # It is the refresh token the refresh was sent with when X issued none.
    #
    # @api public
    # @return [String] the refresh token
    # @example Get the refresh token
    #   tokens.refresh_token
    attr_reader :refresh_token

    # The time the access token expires, or nil when the refresh reported no lifetime
    # @api public
    # @return [Time, nil] the expiration time
    # @example Get the expiration time
    #   tokens.expires_at
    attr_reader :expires_at

    # Initialize the tokens of a refresh
    #
    # @api public
    # @param access_token [String] the access token
    # @param refresh_token [String] the refresh token
    # @param expires_at [Time, nil] the expiration time of the access token
    # @return [OAuth2Tokens] the frozen tokens
    # @example Build the tokens of a refresh
    #   X::OAuth2Tokens.new(access_token: "token", refresh_token: "refresh", expires_at: Time.now + 7200)
    def initialize(access_token:, refresh_token:, expires_at: nil)
      @access_token = access_token
      @refresh_token = refresh_token
      @expires_at = expires_at
      freeze
    end

    # The tokens as a Hash, to store
    #
    # @api public
    # @return [Hash{Symbol => String, Time, nil}] the access token, refresh token, and expiration time
    # @example Store the tokens
    #   store.save(**tokens.to_h)
    def to_h = {access_token:, refresh_token:, expires_at:}

    # Check whether other tokens are the same tokens
    #
    # @api public
    # @param other [Object] the other tokens
    # @return [Boolean] true if the other tokens are of the same class, with the same values
    # @example Compare tokens
    #   tokens == other
    def ==(other) = other.instance_of?(self.class) && to_h.eql?(other.to_h)
    alias_method :eql?, :==

    # The hash of the tokens, for use as a Hash key
    #
    # @api public
    # @return [Integer] the hash
    # @example Get the hash
    #   tokens.hash
    def hash = [self.class, to_h].hash

    # Summarize the tokens for the console without revealing them
    #
    # @api public
    # @return [String] the class name and expiration time
    # @example Inspect tokens
    #   tokens.inspect # => #<X::OAuth2Tokens expires_at=nil>
    def inspect = "#<#{self.class} expires_at=#{expires_at.inspect}>"

    # The state Marshal writes
    #
    # What is written is plain data, led by the number of its format, so that tokens written by one release of 1.x are
    # read by a later one: the tokens and their expiration time, as to_h gives them. It holds the tokens themselves,
    # since tokens are marshalled to be stored, so what Marshal wrote is kept as secret as the tokens are.
    #
    # @api public
    # @return [Array(Integer, Hash{Symbol => String, Time, nil})] the number of the format, then the tokens as a Hash
    # @example Store the tokens of a refresh
    #   X::Client.new(**credentials, on_token_refresh: ->(tokens) { File.binwrite("tokens", Marshal.dump(tokens)) })
    def marshal_dump = [MARSHAL_FORMAT, to_h]

    # Restore tokens Marshal read, built as the constructor builds them, frozen
    #
    # @api public
    # @param state [Array] the state Marshal wrote
    # @return [void]
    # @raise [UnsupportedMarshalFormat] if the state is of a format this release does not read
    # @example Read stored tokens
    #   Marshal.load(File.binread("tokens")).expires_at
    def marshal_load(state)
      format, tokens = state
      raise UnsupportedMarshalFormat, "#{self.class} reads format #{MARSHAL_FORMAT} of Marshal, not #{format.inspect}" unless MARSHAL_FORMAT.eql?(format)

      initialize(**tokens)
    end
  end
end
