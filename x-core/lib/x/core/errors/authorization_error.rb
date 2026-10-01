# frozen_string_literal: true

require "json"
require_relative "client_error"

module X
  # Error raised when X refuses to issue a token
  #
  # X refuses a token when it declines an authorization code, a refresh token, such as one that was revoked or already
  # used, or an app's API key and secret. It answers with a response of 4xx, which the error holds, as any other
  # ClientError holds the response that raised it, and the error code of the response tells the refusals apart. A
  # token endpoint that fails to answer, with 429 Too Many Requests, a server error, a redirect, or a page that is not
  # JSON, such as that of a proxy, firewall, or captive portal, refuses nothing, so it raises the HTTPError, such as
  # the TooManyRequests or ServerError a client retries, or the InvalidResponse, a response of the API raises, rather
  # than this error.
  #
  # It is a ClientError, so code that rescues the failures of a response, as rescue X::HTTPError does around the
  # requests of a client, catches the refresh that X refuses in the middle of one. A client that refreshes an OAuth 2.0
  # token the API rejected raises it when X refuses the refresh, with the Unauthorized that rejected the token as its
  # cause, so rescue both to ask the user to authorize the app again: Unauthorized for credentials the API rejects,
  # and this error for a refresh token X no longer accepts. The redirect back from X that reports a user who declined,
  # or a state that does not match, carries no response of X, so it raises AuthorizationDenied instead.
  #
  # @api public
  class AuthorizationError < ClientError
    # The OAuth 2.0 error code X reported, such as invalid_grant or invalid_request
    #
    # It is read from the JSON of the body, whatever the content type of the response says, as OAuth 2.0 reads it.
    #
    # @api public
    # @return [String, nil] the error code, or nil if X reported none
    # @example Forget the tokens of a user whose refresh token X no longer accepts
    #   rescue X::AuthorizationError => e
    #     store.forget(user) if e.error_code.eql?("invalid_request")
    def error_code
      String.try_convert(Hash.try_convert(JSON.parse(body.to_s))&.[]("error"))
    rescue JSON::ParserError
      nil
    end
  end
end
