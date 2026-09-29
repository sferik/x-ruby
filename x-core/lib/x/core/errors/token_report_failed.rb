# frozen_string_literal: true

require_relative "error"

module X
  # Error raised when on_token_refresh raised for the tokens of an exchange of a code or of a refresh
  #
  # An authorization code works once, and so does a refresh token, so the tokens X issues for either are held in
  # memory alone until on_token_refresh stores them: the first refresh token of X::OAuth2Authorization#client by the
  # client it builds, and the one a refresh issued by the authenticator that refreshed, since the one it replaced is
  # spent. They are not lost to a failure to store them, such as a database that is briefly down: the error holds
  # them, so they can be stored again, and the client, which the exchange builds, or whose request refreshed. The
  # error on_token_refresh raised is the cause, whose message the message ends with.
  #
  # @api public
  class TokenReportFailed < Error
    # The client the authorization built, or whose request refreshed the tokens
    # @api public
    # @return [Client, nil] the client, or nil for a refresh made by an authenticator alone, as its refresh! makes one
    # @example Act for the user once the tokens are stored
    #   rescue X::TokenReportFailed => e
    #     store(e.tokens.refresh_token)
    #     e.client.get("users/me")
    attr_reader :client

    # The tokens of the exchange or the refresh, which on_token_refresh raised for
    # @api public
    # @return [OAuth2Tokens, nil] the tokens, or nil if none were given
    # @example Store the tokens again
    #   rescue X::TokenReportFailed => e
    #     store(e.tokens.refresh_token)
    attr_reader :tokens

    # Initialize the error with the client and the tokens it failed to report
    #
    # @api public
    # @param message [String, nil] the message, or nil for one that says the tokens of an exchange were not stored
    # @param client [Client, nil] the client the authorization built, or whose request refreshed the tokens
    # @param tokens [OAuth2Tokens, nil] the tokens of the exchange or the refresh
    # @return [TokenReportFailed] a new error
    # @example Raise the error for tokens on_token_refresh raised for
    #   raise X::TokenReportFailed.new(client:, tokens:)
    def initialize(message = nil, client: nil, tokens: nil)
      @client = client
      @tokens = tokens
      super(message || "The code was exchanged for tokens, but on_token_refresh raised for them")
    end

    # The message, ending with why on_token_refresh raised
    #
    # It ends with the message of the error on_token_refresh raised, which is the cause, if there is one.
    #
    # @api public
    # @return [String] the message
    # @example Read why the tokens were not stored
    #   error.message # => "The code was exchanged for tokens, but on_token_refresh raised for them: connection refused"
    def to_s = [super, cause&.message].compact.join(": ")
  end
end
