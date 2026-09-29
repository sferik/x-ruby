# frozen_string_literal: true

require_relative "credential_holder"

# A Ruby client for the X API
module X
  # Base class for authentication
  #
  # Subclass it to authenticate with a scheme of your own, overriding {#header}, as the authenticators of x-core do.
  #
  # @api public
  class Authenticator
    include Core::CredentialHolder

    # The HTTP header name for authentication
    AUTHENTICATION_HEADER = "Authorization"

    # Generate the authentication headers for a request, which authenticates as no one
    #
    # A client calls it for every request it sends to the origin of its base URL, and every stream it opens there,
    # once the request is built, just before it is sent, and sends each header it returns, in place of any header of
    # the same name. Its method, URI, headers, and body are set, so an authenticator of your own can sign any of them:
    # subclass X::Authenticator and override this method, and give an instance to the authenticator: of
    # X::Client.new or X::Client#with. A request to another origin, such as one a redirect leads to, is not passed to
    # it, so its headers never leave the origin they were built for. It is called on the thread that sends the
    # request, so one a client shares across threads must be thread-safe.
    #
    # The request is guaranteed to answer four methods alone, which are all the authenticators of x-core read of it:
    # method, the HTTP method as an uppercase String, such as "POST"; uri, the URI::Generic it is sent to, query
    # included; body, the String it sends, or nil for none; and [], the value of a header by its name, in any case,
    # or nil for one it does not send. It is the Net::HTTPRequest the client sends today, but 1.x may pass another
    # object that answers these methods, so an authenticator that reads anything else of it may break.
    #
    # A client refreshes the token of none but its own OAuth 2.0 authenticator, so an authenticator of your own that
    # holds a token that expires refreshes it here. A client given one takes it to authenticate as the app, as it
    # does an X::Authenticator itself, so app_only returns the client, and a stream is opened with it.
    #
    # @api public
    # @param _request [#method, #uri, #body, #[]] the request, which answers method, uri, body, and [] alone
    # @return [Hash{String => String}] the headers that authenticate the request, empty for none
    # @example Authenticate every request with a token an application keeps
    #   class VaultAuthenticator < X::Authenticator
    #     def header(_request) = {AUTHENTICATION_HEADER => "Bearer #{Vault.read("x/bearer_token")}"}
    #   end
    #   client = X::Client.new(authenticator: VaultAuthenticator.new)
    def header(_request)
      {}
    end

    # The identifier of the user the credentials act for, when they name one
    #
    # Only an OAuth 1.0a access token names its user, so every other set of credentials answers nil, and the caller
    # that wants the user of such a client asks the API for it.
    #
    # @api public
    # @return [Integer, nil] the identifier, or nil for credentials that name no user
    # @example Read the user a client acts for without a request
    #   client.authenticator.user_id # => nil
    def user_id
    end

    # Summarize the authenticator for the console without revealing credentials
    #
    # @api public
    # @return [String] the class name
    # @example Inspect an authenticator
    #   authenticator.inspect # => #<X::BearerTokenAuthenticator>
    def inspect
      "#<#{self.class}>"
    end
  end
end
