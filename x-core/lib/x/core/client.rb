# frozen_string_literal: true

require "forwardable"
require_relative "client_internals"
require_relative "connection"
require_relative "credential_holder"
require_relative "rate_limit_handler"
require_relative "redirect_handler"
require_relative "retry_handler"
require_relative "setting_validator"
require_relative "streaming_client"

module X
  module Core
    # A client for interacting with the X API
    #
    # An endpoint is resolved against the base URL, and a request carries the client's credentials to the origin of
    # that base URL alone: the scheme, host, and port it names. An endpoint that names a whole URL of another origin
    # is sent there without them, as a redirect that leads to one is, so that the credentials of the API never reach
    # a host they were not meant for; see {Core::Origin}.
    #
    # The object_class of a request, of a stream, or of a client is one of two things. A class that JSON.parse builds
    # each JSON object of the body into, as it does Hash, the default, OpenStruct, or a Struct, whose new takes no
    # arguments and whose instances take each member with []=. Or anything that responds to from_response, which
    # builds the result from the whole body instead, as the resource classes of x-objects do: it is passed the body
    # parsed into Hashes and Arrays, whatever the array_class, and the client that made the request as client:, and
    # what it returns is what the request returns, or, for a stream, what its block is passed for each object. Later
    # versions of 1.x may pass it keyword arguments of their own, so it accepts the ones it does not read with **, as
    # in def self.from_response(body, client:, **). The signatures of x-core state it as the X::_ResponseBuilder
    # interface.
    #
    # A client keeps its credentials, settings, and connection in an object of x-core it delegates to, and has no
    # private methods but initialize, so that the methods x-objects and x-uploader include into it, which may be
    # named as they like, take the place of none of its own.
    #
    # @api public
    class ::X::Client
      extend Forwardable
      include CredentialHolder

      # Default base URL for the X API
      DEFAULT_BASE_URL = "https://api.x.com/2/"
      # Default class for parsing JSON arrays
      DEFAULT_ARRAY_CLASS = Array
      # Default class for parsing JSON objects
      DEFAULT_OBJECT_CLASS = Hash
      # Default timeout for opening connections in seconds
      DEFAULT_OPEN_TIMEOUT = Connection::DEFAULT_OPEN_TIMEOUT
      # Default timeout for reading responses in seconds
      DEFAULT_READ_TIMEOUT = Connection::DEFAULT_READ_TIMEOUT
      # Default timeout for writing requests in seconds
      DEFAULT_WRITE_TIMEOUT = Connection::DEFAULT_WRITE_TIMEOUT
      # Default time to keep a connection open for the next request to the same host, in seconds
      DEFAULT_KEEP_ALIVE_TIMEOUT = Connection::DEFAULT_KEEP_ALIVE_TIMEOUT
      # Default maximum number of redirects to follow
      DEFAULT_MAX_REDIRECTS = RedirectHandler::DEFAULT_MAX_REDIRECTS
      # Default maximum number of times to retry a request refused for a rate limit
      DEFAULT_MAX_RATE_LIMIT_RETRIES = RateLimitHandler::DEFAULT_MAX_RETRIES
      # Default maximum number of seconds to wait for a rate limit to reset
      DEFAULT_MAX_RATE_LIMIT_WAIT = RateLimitHandler::DEFAULT_MAX_WAIT
      # Default maximum number of times to send an idempotent request again after a failure
      DEFAULT_MAX_RETRIES = RetryHandler::DEFAULT_MAX_RETRIES

      def_delegators :@internals, :open_timeout, :read_timeout, :write_timeout, :keep_alive_timeout, :debug_output,
        :max_redirects, :max_rate_limit_retries, :max_rate_limit_wait, :max_retries

      # The authenticator for API requests
      #
      # It is the one the client was given, or else the one it built of its credentials. A client sends the token
      # requests of an authenticator that makes them, an AppOnlyAuthenticator or an OAuth2Authenticator, over its own
      # connection, with its proxy, timeouts, and debug output, whether it built the authenticator or was given it; an
      # authenticator given to several clients sends them over the connection of the first. The refreshes of an
      # OAuth2Authenticator reach the on_token_refresh of each client that authenticates with it, a refresh reads the
      # stored tokens with the load_tokens of the authenticator, or else with the load_tokens of a client that
      # authenticates with it, and the expires_at of the client is the authenticator's.
      #
      # @api public
      # @return [Authenticator] the authenticator instance
      # @example Check if the OAuth 2.0 token has expired
      #   client.authenticator.token_expired?
      def authenticator = @internals.authenticator

      # A callable passed the OAuth2Tokens of each refresh, and of an authorization
      # @api public
      # @return [#call, nil] the callable, or nil for none
      # @example Read the hook a refresh reports to
      #   client.on_token_refresh
      def on_token_refresh = @internals.on_token_refresh

      # The callable a refresh reads the stored OAuth2Tokens with
      #
      # It returns the tokens in the storage that processes sharing the tokens of a user read, or nil for none there.
      #
      # @api public
      # @return [#call, nil] the callable, or nil for none
      # @example Read the loader a refresh reads stored tokens with
      #   client.load_tokens
      def load_tokens = @internals.load_tokens

      # The API key for OAuth 1.0a authentication
      # @api public
      # @return [String, nil] the API key for OAuth 1.0a authentication
      # @example Get the API key
      #   client.api_key
      def api_key = @internals.api_key

      # The OAuth 2.0 client ID
      # @api public
      # @return [String, nil] the OAuth 2.0 client ID
      # @example Get the client ID
      #   client.client_id
      def client_id = @internals.client_id

      # The time the OAuth 2.0 access token expires, as last refreshed
      #
      # A refresh that reports no lifetime leaves it nil, rather than the time the client was given.
      #
      # @api public
      # @return [Time, nil] the expiration time, or nil if it is not known
      # @example Get the expiration time
      #   client.expires_at
      def expires_at = @internals.expires_at

      # The base URL for API requests
      # @api public
      # @return [String] the base URL for API requests, which ends with a slash
      # @example Get the base URL
      #   client.base_url # => "https://api.x.com/2/"
      def base_url = @internals.base_url

      # The default class for parsing JSON arrays
      # @api public
      # @return [Class] the default class for parsing JSON arrays
      # @example Get the default array class
      #   client.default_array_class # => Array
      def default_array_class = @internals.default_array_class

      # The default class for parsing JSON objects
      #
      # It is a class that JSON.parse builds each JSON object into, or one that responds to from_response and builds
      # the result from the whole body; see {Client}.
      #
      # @api public
      # @return [Class, #from_response] the default class for parsing JSON objects
      # @example Get the default object class
      #   client.default_object_class # => Hash
      def default_object_class = @internals.default_object_class

      # A callable passed an X::Response after each request and streamed object
      #
      # It is the hook of every request a client makes. A block passed to a single request receives the same
      # summary, after this, for code that reads the response of that one request rather than of all of them.
      #
      # @api public
      # @return [#call, nil] the callable, or nil for none
      # @example Read the hook a client reports to
      #   client.on_response
      def on_response = @internals.on_response

      # The headers sent with every request the client makes
      #
      # They are defaults: a header of the same name passed to a request, or to a stream, is sent in place of the
      # client's, and each of them is sent in place of a default of the gem, such as its User-Agent. A header that
      # carries credentials, such as Authorization or Cookie, is dropped by a redirect to another origin, as one
      # passed to a request is.
      #
      # @api public
      # @return [Hash{String => String}] the headers, frozen
      # @example Read the headers a client sends
      #   client.headers # => {"User-Agent" => "my-app/1.0"}
      def headers = @internals.headers

      # Initialize a new X API client
      #
      # @api public
      # @param api_key [String, nil] the API key for OAuth 1.0a authentication
      # @param api_key_secret [String, nil] the API key secret for OAuth 1.0a authentication
      # @param access_token [String, nil] the access token for OAuth authentication
      # @param access_token_secret [String, nil] the access token secret for OAuth 1.0a authentication
      # @param bearer_token [String, nil] the bearer token for authentication
      # @param client_id [String, nil] the OAuth 2.0 client ID
      # @param client_secret [String, nil] the OAuth 2.0 client secret
      # @param refresh_token [String, nil] the OAuth 2.0 refresh token, or nil beside a client ID and access token issued
      #   without offline.access, which authenticate as the user until the access token expires, and cannot refresh
      # @param expires_at [Time, nil] the time the OAuth 2.0 access token expires, after which a request refreshes it
      # @param authenticator [Authenticator, nil] an authenticator to authenticate with in place of credentials, such as
      #   an OAuth2Authenticator built elsewhere, or nil to build one of the credentials; see {#authenticator}
      # @param base_url [String] the base URL for API requests
      # @param open_timeout [Integer, Float, nil] the timeout for opening connections in seconds, or nil for none
      # @param read_timeout [Integer, Float, nil] the timeout for reading responses in seconds, or nil for none
      # @param write_timeout [Integer, Float, nil] the timeout for writing requests in seconds, or nil for none
      # @param keep_alive_timeout [Integer, Float] the time to keep a connection open for the next request to the same
      #   host, in seconds, which a proxy that closes idle connections sooner than X does may need lowered
      # @param debug_output [IO, #<<, nil] the IO object for debug output, or anything else that takes a String with <<,
      #   such as a StringIO. It is written every request and response whole, in the clear: the Authorization header,
      #   the client secret a token request sends, and the tokens a token response holds. Send it to a file you
      #   control while debugging, never to a log that is shipped elsewhere, and leave it nil in production.
      # @param proxy_url [String, URI::Generic, nil] the proxy URL for requests
      # @param default_array_class [Class] the default class for parsing JSON arrays
      # @param default_object_class [Class, #from_response] the default class for parsing JSON objects, or one that
      #   responds to from_response and builds the result from the whole body; see {Client}
      # @param headers [Hash{String => String}] headers sent with every request the client makes, as defaults: a
      #   header of the same name passed to a request is sent in place of one of these, and each of these is sent in
      #   place of a default of the gem, such as its User-Agent
      # @param max_redirects [Integer] the maximum number of redirects to follow, beyond which a redirect raises
      #   TooManyRedirects; 0 follows none, and raises for each redirect that could be followed
      # @param max_rate_limit_retries [Integer] the maximum number of times to retry a request refused for a rate limit,
      #   after waiting for the limit to reset
      # @param max_rate_limit_wait [Integer, Float] the maximum number of seconds to wait for a rate limit to reset; a request
      #   whose limit resets later raises TooManyRequests at once, as does a stream that would wait longer to reconnect,
      #   and a few seconds are added at random to each wait of a request, so that the requests one reset releases are
      #   not sent again in one burst
      # @param max_retries [Integer] the maximum number of times to send a request again after the API failed to answer
      #   it, with a 5xx status or a 408, or after its answer never arrived, which is twice by default and is 0 for a client
      #   that raises at once; a retry waits up to a second before the first and up to twice as long before each after,
      #   but never more than a minute, a random share of each wait taken off so that the requests one failure of the
      #   API ended are not sent again together, or for as long as the response asks when it carries a Retry-After
      #   header, whichever is longer, and a response that asks for longer than a minute raises at once; a 429 is not
      #   among these, and waits for its rate limit to reset as max_rate_limit_wait allows, however long past a minute; only a GET, PUT, or DELETE is sent again, since
      #   the API may have acted on a POST whose answer never arrived, and one whose answer never arrived is sent again
      #   only when it never reached the API, such as for a connection refused or one that timed out opening, since the
      #   API bills a read it answered, such as one that timed out reading its response, whether or not the answer came
      # @param on_response [#call, nil] a callable passed an X::Response after every request, failed ones included, and
      #   every object a stream delivers; a block passed to a single request receives the same summary, after this
      # @param on_token_refresh [#call, nil] a callable passed the OAuth2Tokens of each refresh, to store them; the
      #   refreshes are reported one at a time, in the order they were made, and one already replaced is not reported;
      #   the client of OAuth2Authorization#client passes it the tokens of the exchange of the code as well; a callable
      #   that raises, as one whose storage is briefly down may, raises TokenReportFailed from the request that
      #   refreshed, which holds the tokens, since the refresh token they replaced is spent, and the client, with the
      #   error of the callable as its cause
      # @param load_tokens [#call, nil] a callable that takes no arguments and returns the OAuth2Tokens in the storage
      #   that on_token_refresh writes to, or nil for none there, for processes that share the tokens of a user: X
      #   accepts a refresh token once, so a refresh reads the storage first, under its lock, and takes the tokens there
      #   in place of its own when their refresh token is another, as it is once another process has refreshed; it
      #   sends the request with them when their access token has not expired, and refreshes with them when it has,
      #   and a refresh X refuses for a refresh token another process spent reads the storage again, and takes the
      #   tokens there in place of raising; the tokens it takes came from the storage, so on_token_refresh is not
      #   passed them; see {#authenticator}
      # @return [Client] a new client instance
      # @raise [ArgumentError] if credentials are given that do not form a complete set, which would send requests
      #   without them, or authenticate as the app rather than a user
      # @raise [ArgumentError] if a credential is an empty String, as an environment variable that is not set is often
      #   read, which would send an Authorization header that authenticates nothing
      # @raise [ArgumentError] if expires_at is neither a Time nor nil
      # @raise [ArgumentError] if an authenticator is given that is not an Authenticator, or beside credentials or
      #   expires_at, which it would leave unused
      # @raise [ArgumentError] if a timeout is neither a finite number of seconds of at least 0 nor, for any but
      #   keep_alive_timeout, nil, or if a maximum is not a count or a number of seconds of at least 0
      # @raise [ArgumentError] if base_url is not an absolute http or https URL with no user, password, query, or
      #   fragment, or headers are not a Hash that names each header with a String or a Symbol and gives it a String
      # @raise [ArgumentError] if on_response, on_token_refresh, or load_tokens is neither nil nor responds to call
      # @raise [ArgumentError] if default_array_class is not a Class, or default_object_class is neither a Class nor
      #   responds to from_response, which a response would be parsed with once the API had answered the request
      # @example Create a client with bearer token authentication
      #   client = X::Client.new(bearer_token: "your_bearer_token")
      # @example Create a client with OAuth 2.0 authentication that stores the tokens of each refresh
      #   client = X::Client.new(client_id: "id", client_secret: "secret", access_token: "token", refresh_token: "refresh",
      #     expires_at: Time.now + 7200, on_token_refresh: ->(tokens) { store.save(tokens.refresh_token) })
      # @example Share the tokens of a user among processes, which store each refresh and read the store before one
      #   stored = store.load(user)
      #   client = X::Client.new(client_id: "id", **stored.to_h,
      #     on_token_refresh: ->(tokens) { store.save(user, tokens) },
      #     load_tokens: -> { store.load(user) })
      # @example Create a client with OAuth 1.0a authentication
      #   client = X::Client.new(api_key: "key", api_key_secret: "secret", access_token: "token", access_token_secret: "token_secret")
      # @example Create a client that authenticates with an authenticator built elsewhere
      #   client = X::Client.new(authenticator: X::OAuth2Authenticator.new(client_id: "id", access_token: "token",
      #     refresh_token: "refresh", expires_at: Time.now + 7200), on_token_refresh: ->(tokens) { store.save(tokens) })
      # @example Create a client that fetches an app-only bearer token with the API key and secret
      #   client = X::Client.new(api_key: "key", api_key_secret: "secret")
      # @example Create a client that retries a rate-limited request up to three times
      #   client = X::Client.new(bearer_token: "your_bearer_token", max_rate_limit_retries: 3)
      # @example Create a client that raises at once rather than send a lookup again the API failed to answer
      #   client = X::Client.new(bearer_token: "your_bearer_token", max_retries: 0)
      # @example Create a client that names the application in the User-Agent of every request
      #   client = X::Client.new(bearer_token: "your_bearer_token", headers: {"User-Agent" => "my-app/1.0"})
      def initialize(api_key: nil, api_key_secret: nil, access_token: nil, access_token_secret: nil,
        bearer_token: nil, client_id: nil, client_secret: nil, refresh_token: nil, expires_at: nil, authenticator: nil,
        base_url: DEFAULT_BASE_URL,
        open_timeout: DEFAULT_OPEN_TIMEOUT,
        read_timeout: DEFAULT_READ_TIMEOUT,
        write_timeout: DEFAULT_WRITE_TIMEOUT,
        keep_alive_timeout: DEFAULT_KEEP_ALIVE_TIMEOUT,
        debug_output: nil,
        proxy_url: nil,
        default_array_class: DEFAULT_ARRAY_CLASS,
        default_object_class: DEFAULT_OBJECT_CLASS,
        headers: {},
        max_redirects: DEFAULT_MAX_REDIRECTS,
        max_rate_limit_retries: DEFAULT_MAX_RATE_LIMIT_RETRIES,
        max_rate_limit_wait: DEFAULT_MAX_RATE_LIMIT_WAIT,
        max_retries: DEFAULT_MAX_RETRIES,
        on_response: nil,
        on_token_refresh: nil,
        load_tokens: nil)
        @internals = ClientInternals.new(self, api_key:, api_key_secret:, access_token:, access_token_secret:, bearer_token:,
          client_id:, client_secret:, refresh_token:, expires_at:, authenticator:, base_url:, open_timeout:, read_timeout:,
          write_timeout:, keep_alive_timeout:, debug_output:, proxy_url:, default_array_class:, default_object_class:,
          headers:, max_redirects:, max_rate_limit_retries:, max_rate_limit_wait:, max_retries:, on_response:,
          on_token_refresh:, load_tokens:)
      end

      # Summarize the client for the console without revealing credentials
      #
      # @api public
      # @return [String] the class name, base URL, and authenticator
      # @example Inspect a client
      #   client.inspect # => #<X::Client base_url="https://api.x.com/2/" authenticator=#<X::BearerTokenAuthenticator>>
      def inspect
        "#<#{self.class} base_url=#{base_url.inspect} authenticator=#{authenticator.inspect}>"
      end

      # Copy the client with some of its options changed
      #
      # A copy that authenticates with OAuth 2.0 shares the client's authenticator, so that a refresh by either
      # client reaches the other, since X accepts a refresh token once, unless it is given a client ID, client secret,
      # access token, or refresh token that the authenticator does not hold. It shares it whatever the tokens are when
      # it is built, so a refresh on another thread while it is built reaches it too. A refresh then passes the
      # tokens it issued to the on_token_refresh of each client that shares it, once for each distinct callable.
      #
      # A copy of a client that was given its authenticator shares it, unless the copy is given a credential, which
      # replaces it, or an authenticator of its own, which also replaces the credentials of a client that holds them.
      #
      # A copy that opens its connections as the client does, with the same timeouts, keep-alive timeout, debug output,
      # and proxy, shares the connections the client keeps open, so that a copy made for each request, such as to send
      # a header of its own, opens none of its own; {#close} on either closes them for both, and a later request of
      # either opens them again.
      #
      # @api public
      # @param options [Hash] the options to change, as accepted by initialize
      # @return [Client] a new client with the same credentials and settings, apart from the options given
      # @example Derive an API v1.1 client
      #   v1_client = client.with(base_url: "https://api.x.com/1.1/")
      # @example Derive an app-only client from the API key and secret
      #   app_client = client.with(access_token: nil, access_token_secret: nil)
      # @example Derive a client that authenticates with another authenticator
      #   user_client = app_client.with(authenticator: X::OAuth2Authenticator.new(**stored_tokens))
      def with(**options) = @internals.with(self, options) # steep:ignore DifferentMethodParameterKind

      # A client that authenticates as the app, for the endpoints that refuse OAuth 1.0a
      #
      # A client that authenticates as a user, signing with OAuth 1.0a or with OAuth 2.0, returns a copy that
      # authenticates with the app's bearer token: the one it was given, or one it fetches with its API key and secret
      # the first time. It returns the same copy, with the connections it keeps open, from then on, since the
      # credentials and settings of a client never change; threads that ask for the copy together get one. A client
      # with a bearer token or an API key and secret alone already authenticates as the app, and is returned as it is,
      # as is one given an authenticator that authenticates as the app, or as no one. A client given an
      # OAuth1Authenticator fetches the token with the API key and secret it signs with. A client that authenticates
      # with OAuth 2.0 as a user and holds neither the app's bearer token nor its API key and secret, as a client
      # given an OAuth2Authenticator holds neither, raises, rather than send the user's credentials to an endpoint
      # that would refuse them with 403 Forbidden.
      #
      # @api public
      # @return [Client] a copy that authenticates with the bearer token, or the client itself
      # @raise [UnsupportedOperation] if the client authenticates with OAuth 2.0 as a user and holds no credentials of
      #   the app
      # @example Add a filtered stream rule, which takes app-only authentication
      #   client.app_only.post("tweets/search/stream/rules", {add: [{value: "ruby"}]})
      def app_only = @internals.app_only(self)

      # Perform a GET request to the X API
      #
      # @api public
      # @param endpoint [String] the endpoint, relative to the base URL with or without a leading slash, with or
      #   without a query string
      # @param params [Hash, nil] query parameters appended to the endpoint; nil values are dropped and arrays are joined with commas
      # @param headers [Hash] additional headers for the request
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that responds to
      #   from_response and builds the result from the whole body; see {Client}
      # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
      # @raise [ArgumentError] if the endpoint is not a valid URL, or does not resolve to an http or https URL, before
      #   the request is sent
      # @raise [ArgumentError] if array_class is not a Class, or object_class is neither a Class nor responds to
      #   from_response, before the request is sent
      # @yieldparam response [Response] the summary of each response the request got, as {#on_response} receives it
      # @example Get a user by username
      #   client.get("users/by/username/sferik")
      # @example Get users by identifier, requesting only some fields
      #   client.get("users", params: {ids: [1, 2], "user.fields": %w[id username]})
      # @example Read what a response reported of the rate limit it spent
      #   user = client.get("users/me") { |response| limit = response.rate_limit }
      def get(endpoint, params: nil, headers: {}, array_class: default_array_class, object_class: default_object_class, &)
        @internals.execute_request(self, :get, endpoint, params:, headers:, array_class:, object_class:, &)
      end

      # Perform a POST request to the X API
      #
      # @api public
      # @param endpoint [String] the endpoint, relative to the base URL with or without a leading slash, with or
      #   without a query string
      # @param body [String, Hash, Array, nil] the request body; a body that is not a String, such as a Hash or an
      #   Array, is encoded as JSON
      # @param params [Hash, nil] query parameters appended to the endpoint
      # @param form [Hash, nil] fields to send as a form-encoded body, in place of a body
      # @param headers [Hash] additional headers for the request
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that responds to
      #   from_response and builds the result from the whole body; see {Client}
      # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
      # @raise [ArgumentError] if both a body and form fields are given, or a keyword is given that the method takes
      #   none of, as the fields of a body given without the braces of a Hash are, before the request is sent
      # @raise [ArgumentError] if the endpoint is not a valid URL, or does not resolve to an http or https URL, before
      #   the request is sent
      # @raise [ArgumentError] if array_class is not a Class, or object_class is neither a Class nor responds to
      #   from_response, before the request is sent
      # @yieldparam response [Response] the summary of each response the request got, as {#on_response} receives it
      # @example Create a post
      #   client.post("tweets", {text: "Hello, World!"})
      # @example Post a form to the v1.1 API
      #   v1_client.post("account/settings.json", form: {lang: "en"})
      def post(endpoint, body = nil, params: nil, form: nil, headers: {}, array_class: default_array_class, object_class: default_object_class, **unknown, &) # steep:ignore DifferentMethodParameterKind
        SettingValidator.no_unknown_keywords!(:post, endpoint, unknown)
        @internals.execute_request(self, :post, endpoint, body:, params:, form:, headers:, array_class:, object_class:, &)
      end

      # Perform a PUT request to the X API
      #
      # @api public
      # @param endpoint [String] the endpoint, relative to the base URL with or without a leading slash, with or
      #   without a query string
      # @param body [String, Hash, Array, nil] the request body; a body that is not a String, such as a Hash or an
      #   Array, is encoded as JSON
      # @param params [Hash, nil] query parameters appended to the endpoint
      # @param form [Hash, nil] fields to send as a form-encoded body, in place of a body
      # @param headers [Hash] additional headers for the request
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that responds to
      #   from_response and builds the result from the whole body; see {Client}
      # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
      # @raise [ArgumentError] if both a body and form fields are given, or a keyword is given that the method takes
      #   none of, as the fields of a body given without the braces of a Hash are, before the request is sent
      # @raise [ArgumentError] if the endpoint is not a valid URL, or does not resolve to an http or https URL, before
      #   the request is sent
      # @raise [ArgumentError] if array_class is not a Class, or object_class is neither a Class nor responds to
      #   from_response, before the request is sent
      # @yieldparam response [Response] the summary of each response the request got, as {#on_response} receives it
      # @example Update a resource
      #   client.put("some/endpoint", {key: "value"})
      def put(endpoint, body = nil, params: nil, form: nil, headers: {}, array_class: default_array_class, object_class: default_object_class, **unknown, &) # steep:ignore DifferentMethodParameterKind
        SettingValidator.no_unknown_keywords!(:put, endpoint, unknown)
        @internals.execute_request(self, :put, endpoint, body:, params:, form:, headers:, array_class:, object_class:, &)
      end

      # Perform a DELETE request to the X API
      #
      # @api public
      # @param endpoint [String] the endpoint, relative to the base URL with or without a leading slash, with or
      #   without a query string
      # @param params [Hash, nil] query parameters appended to the endpoint
      # @param headers [Hash] additional headers for the request
      # @param array_class [Class] the class for parsing JSON arrays
      # @param object_class [Class, #from_response] the class for parsing JSON objects, or one that responds to
      #   from_response and builds the result from the whole body; see {Client}
      # @return [Object, nil] the parsed response body, or what an object_class that responds to from_response builds
      # @raise [ArgumentError] if the endpoint is not a valid URL, or does not resolve to an http or https URL, before
      #   the request is sent
      # @raise [ArgumentError] if array_class is not a Class, or object_class is neither a Class nor responds to
      #   from_response, before the request is sent
      # @yieldparam response [Response] the summary of each response the request got, as {#on_response} receives it
      # @example Delete a post
      #   client.delete("tweets/1234567890")
      def delete(endpoint, params: nil, headers: {}, array_class: default_array_class, object_class: default_object_class, &)
        @internals.execute_request(self, :delete, endpoint, params:, headers:, array_class:, object_class:, &)
      end

      # A client for the streaming endpoints, which reads and reconnects differently
      #
      # @api public
      # @param read_timeout [Integer, Float, nil] the timeout for reading from a stream in seconds, as
      #   {StreamingClient#initialize} takes it
      # @param max_reconnects [Integer, Float] the maximum number of times in a row to reconnect a stream that drops, as
      #   {StreamingClient#initialize} takes it
      # @return [StreamingClient] a streaming client that shares this client's credentials and settings
      # @raise [ArgumentError] if the read timeout is neither a finite number of seconds of at least 0 nor nil, or the
      #   maximum number of reconnects is neither a count nor Float::INFINITY
      # @example Stream filtered posts, giving up after five reconnects in a row
      #   client.streaming(max_reconnects: 5).stream("tweets/search/stream") { |post| puts post }
      def streaming(read_timeout: StreamingClient::DEFAULT_READ_TIMEOUT, max_reconnects: StreamingClient::DEFAULT_MAX_RECONNECTS)
        StreamingClient.new(self, read_timeout:, max_reconnects:)
      end

      # Send a request that is safe to send twice again after a failure
      #
      # The client sends no POST again, since the API may have acted on one whose answer never arrived, and sends no
      # request again after its answer failed to arrive, since the API bills a read it answered whether or not the
      # answer arrived. A request that is safe to send again anyway, such as the chunk of an upload, which names the
      # segment it is appended at and which the API bills nothing for, is sent again with this: after a ServerError, a
      # RequestTimeout, or a NetworkError of any kind, up to max_retries times, as the client sends an idempotent
      # request again, after the wait a response asks for, or a backoff that doubles with each retry up to a minute and
      # is cut short at random. A response that asks to be left alone for longer than a minute raises at once. The block must build
      # its request anew each time, so that each attempt is signed afresh, as a request of the client is.
      #
      # Wrap a request the client sends no more than once, such as a POST: the client sends a GET, a PUT, or a DELETE
      # again itself, so one wrapped in this is sent max_retries times more for each time this sends it, nine times in
      # all with the defaults, rather than three.
      #
      # @api public
      # @yield sends the request
      # @return [Object] what the block returns
      # @raise [NetworkError] if the request fails once more than the retries allow
      # @raise [ServerError, RequestTimeout] if the API fails to answer once more than the retries allow, or asks for a
      #   wait longer than a minute
      # @example Append a chunk of an upload, again after a failure
      #   client.with_retries { client.post("media/upload/1/append", body, headers:) }
      def with_retries(&) = @internals.with_retries(&)
      # Close the connections the client keeps open between requests
      #
      # A later request opens a connection again. A client and the copies made of it with {#with} that open their
      # connections as it does share their connections, as the app-only copy of a client that signs with OAuth 1.0a
      # does, so closing one closes them for all of them.
      #
      # @api public
      # @return [void]
      # @example Close the connections before a long pause
      #   client.close
      def close = @internals.close
    end
  end
end
