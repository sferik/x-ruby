# Changelog

All notable changes to `x-core` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`x-core` is released in lockstep with the other gems of the [x-ruby](https://github.com/sferik/x-ruby) repository, at one version across `x-core`, `x-uploader`, `x-streaming`, `x-objects`, and `x`. This file holds the changes to the HTTP layer; [the changelog of the repository](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) holds the changes to every gem.

## [1.0.0] - 2026-10-02

The first release of `x-core`, which 1.0.0 split out of the `x` gem. The entries below are the changes since `x` 0.19, the last release before the split; see [UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) for the changes that code written for 0.19 needs.

### Added
* Split the `x` gem into five gems released in lockstep, at one version
  * `x-core` (the HTTP client), `x-uploader` (uploads), `x-streaming` (streams and their rules), `x-objects` (resources).
  * `x` is a meta-gem that depends on all four and mixes their object, upload, and streaming methods into `X::Client`.
  * `x-core` declares `X::Error`, the base class of every error the gems raise.
  * Public classes sit directly under `X`; `X::Objects::Error`, `X::Uploader::Error`, and `X::Streaming::Error` catch one gem's.
  * Each gem depends on the others it needs with `>= 1.0.0, < 2`, so a later 1.x of one installs beside the others, and never an earlier one.
* Add `X::Client#get_stream`, which opens a GET request whose body its block reads as it arrives
  * It sends the client's credentials, headers, timeouts, and proxy, and refreshes a rejected token, as any request does.
  * A failed response raises its `X::HTTPError`, once `on_response` is passed it, without reaching the block.
  * The block is passed the `Net::HTTPResponse` before its body is read, and `get_stream` returns what the block returns.
  * An error `read_body` raises from the socket raises `X::NetworkError`; any other error of the block is raised as it was.
  * `x-streaming` reads the streams of the API with it.
* Add `X::Client#with_retries`, `memoized`, and `memoize`, kept throughout 1.x for the gems that extend a client
  * `with_retries` sends a request again after a failure, as `x-uploader` sends each chunk of an upload.
  * `memoize` keeps a value under a key for the authenticator of the client, and `memoized` reads it, as `x-objects` keeps the authenticated user.
* Pass a block to `get`, `post`, `put`, or `delete` to receive the `X::Response` of each response that request gets
  * It is passed what the client's `on_response` is passed, after it, failed responses and each retry among them.
* Add `X::Core.gem_version`, which returns `X::Core::VERSION` as a `Gem::Version`
* Add the `headers:` option of `X::Client.new`, headers sent with every request and stream the client makes
  * They are a Hash of String or Symbol names to String values; anything else raises `ArgumentError`.
  * In any `headers:`, a Symbol's underscores become hyphens: `{content_type: "text/plain"}` sends `content-type`.
  * A request's or `get_stream`'s header replaces the client's of the same name, which replaces the gem's default.
  * Header names are case-insensitive, and a redirect to another origin drops the ones that carry credentials.
  * `X::Client#headers` reads them back frozen, each named by a String: `user_agent:` reads as `{"user-agent" => ...}`.
  * Token requests send them too, with the gem's `User-Agent`, beneath the token request's own credentials; a client's `Authorization` header is never sent with one.
* Raise `ArgumentError` from `X::Client.new` for a `base_url` that is not an absolute http or https URL
  * A `base_url` with a user, password, query, or fragment raises too.
* Pass a resource class, such as `X::User`, as the `object_class` of a request to build objects from the response
  * A list builds an `X::Page`, which holds the response's `meta`, such as its `next_token`, and the problems it reported.
  * A list answered with no `data`, or a lookup by ids that finds none, builds an empty `X::Page` rather than nil.
  * An `object_class` that responds to `from_response` is passed the parsed body and `client:`, and builds the result.
  * `from_response` must take the keywords it does not read with `**`; the signatures type it as `X::_ResponseBuilder`.
* Pass query parameters to `get`, `post`, `put`, `delete`, and `get_stream` as `params:`
  * nil values are dropped, Arrays are joined with commas, and a `Time` is sent in UTC as ISO 8601.
* Encode a `post` or `put` body that is not a String, such as a Hash or an Array, as JSON
* Send form fields as a form-encoded body with the `form:` option of `post` and `put`
  * Fields are encoded as `params:` are.
  * A request given both a body and `form:` raises `ArgumentError`.
* Authenticate as the app given only an `api_key` and `api_key_secret`, with `X::AppOnlyAuthenticator`
  * It fetches a bearer token with the client credentials grant on the first request, and keeps it.
  * A token the base URL's origin rejects with 401 is fetched again, and the request or stream is sent once more.
* Add `X::Client#with`, which copies a client with some options of `X::Client.new` changed
  * For example `client.with(base_url: "https://api.x.com/1.1/")`, or `with(access_token: nil, access_token_secret: nil)`.
  * A copy given no new OAuth 2.0 credentials shares the client's OAuth 2.0 authenticator, and so its refreshes.
  * Such a copy given `expires_at` raises `ArgumentError`, since the expiration belongs to the shared token.
  * A copy that does not share it holds no `refresh_token`, `expires_at`, `scopes`, or token hooks unless given them.
  * A copy with the same app credentials and base URL shares the app-only bearer token the client fetched.
* Add the `authenticator:` option of `X::Client.new` and `X::Client#with`, to authenticate with an `X::Authenticator`
  * It raises `ArgumentError` beside credentials, `expires_at`, or `scopes`, or for what is not an `X::Authenticator`.
  * A custom one subclasses `X::Authenticator` and overrides `headers`, reading what `X::_AuthenticatorRequest` types.
  * A client sends its token requests over its own connection, and refreshes reach the `save_tokens` of every client.
  * A client given an `X::OAuth2Authenticator` holds no app credentials, so its `app_only` raises `X::UnsupportedOperation`.
* Add `inspect` to `X::Client` and the authenticators, which never reveals credentials
* Keep the headers passed to `get`, `post`, `put`, and `delete` across redirects
* Pass an `X::Response` to the client's `on_response` after every request, and for each object a stream delivers
  * It reads rate limits with `rate_limits` and `rate_limit`, and counts the resources returned with `resource_counts`.
  * An `on_response` that is neither nil nor responds to `call` raises `ArgumentError` when the client is built.
* Add `X::Response#headers` and `X::HTTPError#headers`, a frozen Hash of the response headers with lowercase names
  * Repeated fields are joined with a comma; read each cookie with `http_response.get_fields("set-cookie")`.
* Retry a request refused for a rate limit up to `max_rate_limit_retries` times, 0 by default, after the wait it asks for
  * It waits no longer than `max_rate_limit_wait` seconds, 900 by default; a later reset raises at once.
  * A refusal that names no wait waits a minute, doubling for each retry after; each wait adds up to 5 random seconds.
  * A refusal for the project's usage cap, which `X::Problem#usage_capped?` tells apart, raises at once.
* Refresh an OAuth 2.0 access token when it expires, or when the base URL's origin rejects it with 401, and send again
  * The `expires_at:` of `X::Client.new` must be a `Time`; anything else raises `ArgumentError`.
  * A token refreshed less than a minute ago is not refreshed again, and a 401 from another origin refreshes nothing.
  * Requests on several threads refresh once; `X::Client#expires_at` reads the expiration of the last refresh.
  * A refresh that reports no lifetime forgets the expiration, rather than refresh again on every request.
* Store the tokens of each refresh with the `save_tokens:` callable of `X::Client.new`, passed an `X::OAuth2Tokens`
  * Refreshes are reported one at a time, in order, leaving out one already replaced.
  * Each hook runs even when another raises; then `X::TokenReportFailed` is raised, holding the `tokens` and `client`.
  * A `save_tokens` that is neither nil nor responds to `call` raises `ArgumentError` when the client is built.
  * An authenticator reports to no hook of its own; its `refresh!` returns the frozen `X::OAuth2Tokens` of the refresh.
* Add `X::OAuth2Tokens`, the frozen `access_token`, `refresh_token`, `expires_at`, and `scopes` of a refresh or authorization
  * It writes itself with Marshal, YAML, and `to_json` in a versioned format that every 1.x release reads back.
  * `X::OAuth2Tokens.from_json` reads its JSON, or that JSON's Hash, back; `inspect` names neither token.
  * `X::OAuth2Tokens.new` raises `ArgumentError` for an empty or non-String token, or an `expires_at` that is not a `Time`.
* Share a user's tokens among processes with a `load_tokens:` callable that returns the stored `X::OAuth2Tokens`, or nil
  * `X::Client.new`, `X::Client#with`, `X::OAuth2Authorization#client`, and `X::OAuth2Authenticator.new` take it.
  * A refresh reads the store under its lock first, and takes tokens another process refreshed in place of its own.
  * A refresh X refuses with `invalid_request` or `invalid_grant` reads the store again rather than raise.
  * Tokens it loads are not passed to `save_tokens`.
  * A `load_tokens` that does not respond to `call` raises `ArgumentError`; one returning anything else raises `TypeError`.
* Read the scopes X granted an OAuth 2.0 token with `scopes` on `X::OAuth2Tokens`, `X::OAuth2Authenticator`, and `X::Client`
  * They are a frozen Array of Strings, or nil when unknown, and may be fewer than the app asked for.
  * `X::Client.new`, `with`, and `X::OAuth2Authenticator.new` take `scopes:`, as in `X::Client.new(client_id:, **tokens.to_h)`.
  * `scopes` that are not an Array of scope Strings, or that are given without OAuth 2.0 credentials, raise `ArgumentError`.
* Add `X::HTTPError#status`, `#body`, `#problems`, and `#problem`, to read what the API said without its response
  * `status` is an Integer, as `X::Response#status` is.
  * `problems` are the `X::Problem`s the body names; `problem` is the one it describes itself, or the first it names.
  * `http_response` holds the `Net::HTTPResponse` on `X::HTTPError` and `X::InvalidResponse`, as on `X::Response`.
* Raise an `X::ClientError` subclass of its own for the statuses 405, 408, 415, and 451, which raised `X::ClientError` itself
  * They are `X::MethodNotAllowed`, `X::RequestTimeout`, `X::UnsupportedMediaType`, and `X::UnavailableForLegalReasons`.
* Raise `X::PaymentRequired`, an `X::ClientError`, for a 402, which X sends when the paying account has no credit left
* Name the request in the errors `X::HTTPError`, `X::NetworkError`, `X::InvalidResponse`, and `X::TooManyRedirects`
  * Each reads its `http_method` and `uri`, and its message names it, as in `GET /2/users/1: Could not find user`.
  * The message leaves out the query, which `uri` keeps, and a redirected request is named by the last request sent.
* Add `X::Authenticator#user_id`, the user an OAuth 1.0a access token acts for, or nil for credentials that name none
* Keep connections open between requests to the same host, up to 16 idle per host
  * The `keep_alive_timeout:` of `X::Client` and `X::OAuth2Authorization` keeps them for 30 seconds by default.
  * A connection whose request fails is closed, and a forked process opens its own.
  * Copies made with `X::Client#with` that connect as the client does share its connections, as its app-only copy does.
  * `X::Client#close` closes them, and those of the copies that share them; a later request opens one again.
* Add `X::Client#app_only`, a copy of a client that authenticates as a user which authenticates as the app instead
  * It holds the app's bearer token: the one the client was given, or one fetched once with the app's API key and secret.
  * It returns the same copy each time, and a copy made with `with` that holds the same app credentials shares its token.
  * An OAuth 2.0 user client without app credentials raises `X::UnsupportedOperation`, an `X::Error` of `x-core`.
  * The gems send its requests to app-only endpoints, such as streams, as the user, so X's 403 raises `X::Forbidden`.
* Refresh the tokens of a public OAuth 2.0 client, given a `client_id`, `access_token`, and `refresh_token` without a secret
  * The refresh sends the client ID in its body rather than authenticate with a secret.
* Authenticate as a user with an OAuth 2.0 access token that is not refreshed, given no `refresh_token`
  * `refresh_token:` is optional for `X::Client.new`, `X::Client#with`, and `X::OAuth2Authenticator.new`.
  * A rejected access token raises `X::Unauthorized`, and `refresh!` raises `X::UnsupportedOperation`.
* Authorize an app to act for a user with the OAuth 2.0 authorization code flow and PKCE, with `X::OAuth2Authorization`
  * It builds the URL that asks the user, with a state and code verifier to store until X redirects back.
  * It exchanges the code of the redirect for `tokens`, an `X::OAuth2Tokens` that holds no app secret, or for a `client`.
  * A declined authorization, a mismatched state, or an invalid redirect raises `X::AuthorizationDenied`.
  * A code X refuses raises `X::AuthorizationError`; invalid options raise `ArgumentError` before the code is spent.
  * `client` passes the tokens of the exchange to its `save_tokens` before it returns the client.
  * It takes `headers:`, which it exchanges the code with and gives the client it builds, as a gateway may require.
* Add `X::InvalidResponse#body`, `#status`, and `#headers`, to read a successful response, or stream line, that is not JSON
  * `body` falls back to the body of the response once it has been read whole, and never reads a stream.
* Add `X::TooManyRequests#exhausted_rate_limits` and `#limiting_rate_limit`, the used-up limits and the one to wait for
* Add a constant of `X::Client` for the default of each setting
  * New: `DEFAULT_MAX_REDIRECTS`, `DEFAULT_MAX_RATE_LIMIT_RETRIES`, `DEFAULT_MAX_RATE_LIMIT_WAIT`, and `DEFAULT_MAX_RETRIES`.
  * `DEFAULT_KEEP_ALIVE_TIMEOUT` is new too, and the `DEFAULT_*_TIMEOUT`s of `X::Connection` move to `X::Client`.
* Ship this changelog with `x-core`, which the `changelog_uri` of its gemspec names
* Ship a `.yardopts` with `x-core`, so its documentation on rubydoc.info leaves out the private API
* Send a request again when the API fails to answer it, up to `max_retries` times, 2 by default
  * A `GET`, `PUT`, or `DELETE` is sent again after an `X::ServerError`, `X::RequestTimeout`, or unsent `X::NetworkError`.
  * A `POST`, and any other 4xx, raises at once; `max_retries: 0` raises at once for any failure.
  * The wait starts at up to a second and doubles to at most a minute, with jitter, or follows a longer `Retry-After`.
  * A `Retry-After` of more than a minute raises at once.
  * An error that `on_response`, a request's block, or `from_response` raises is never sent again.
* Raise `ArgumentError` from `X::Client.new` and `X::Client#with` for an invalid setting, naming it and the value given
  * `max_redirects`, `max_rate_limit_retries`, and `max_retries` must be Integers of at least 0.
  * `max_rate_limit_wait` must be a number of seconds of at least 0, not NaN, and `keep_alive_timeout` a finite one.
  * `open_timeout`, `read_timeout`, and `write_timeout` must be finite numbers of seconds of at least 0, or nil for none.
  * `default_array_class` must be a Class, and `default_object_class` a Class or respond to `from_response`.
  * `X::OAuth2Authorization.new` checks its timeouts, and a request its `array_class` and `object_class`, the same way.
* Add `X::Problem`, which describes a problem the API reported of a request
  * It reads `title`, `detail`, `type`, `resource_type`, `resource_id`, `parameter`, `value`, and `message`.
  * It compares by value, writes itself with Marshal and YAML in a versioned format every 1.x reads, and as JSON with `to_json`.
  * `about?` tells whether it names a resource, or an Integer or String identifier, comparing them as Strings.
  * A format it does not read raises `X::UnsupportedMarshalFormat`, an `X::Error` that `x-core` declares for every gem.
  * `X::HTTPError#problem` returns one, and `x-objects` reports them for a successful response.

### Changed
* Hold `X::Core::VERSION` in a String rather than a `Gem::Version`; compare it with `X::Core.gem_version`
* Require Ruby 3.4 or later
* Keep secret credentials private on a client and its authenticator, so no reader, `inspect`, or serialization reveals them
  * Gone from `X::Client`: `api_key_secret`, `access_token`, `access_token_secret`, `bearer_token`, and `client_secret`.
  * `refresh_token` is gone too: store tokens from the `X::OAuth2Tokens` that `save_tokens` is passed.
  * Authenticators no longer read their secrets or tokens; `api_key`, `client_id`, and `expires_at` stay public.
  * An authenticator's `headers` still returns the `Authorization` header it sends, which holds a bearer or OAuth 2.0 token.
* Raise `TypeError` when a client, an authenticator, or an `X::OAuth2Authorization` is written out
  * That is `Marshal.dump`, `YAML.dump`, `as_json`, and `to_json`, which ActiveSupport's `render json:` calls.
  * They wrote credentials in the clear in 0.19; keep credentials in a secret store, and tokens as `X::OAuth2Tokens`.
* Keep a client's proxy URL private, since it can hold the proxy's user and password
  * `X::Client` no longer reads `proxy_url`, and `inspect` summarizes it without the user and password.
* Send a client's credentials to the origin of its `base_url` alone
  * An endpoint or stream naming a URL of another origin is sent without `Authorization`, `Cookie`, or `Proxy-Authorization`.
  * Another API version at that origin, such as `https://api.x.com/1.1/account/settings.json`, still carries them.
* Open connections with a 10-second timeout rather than 60; `read_timeout` and `write_timeout` stay at 60 seconds
* Read only the rate limits a response reports in full, with a limit, remaining count, and reset time, in base 10
  * `X::TooManyRequests#retry_after` no longer raises `KeyError` or `ArgumentError` for a missing or malformed header.
* Read the `Retry-After` header of a refused response with `X::HTTPError#retry_after`, in seconds or as an HTTP date
  * It is nil for a response without one.
  * `X::TooManyRequests#retry_after` reads it, then falls back on `#reset_in`, which it was an alias of.
  * The retries of a client and the reconnects of a stream wait for it.
* Send requests to `api.x.com` rather than `api.twitter.com` by default
* Rename `X::ConnectionException`, the error for 409 Conflict, to `X::Conflict`
* Rename `X::HTTPError#response` to `#http_response`, the name `X::Response` reads it by
  * The `response` of `X::RateLimit` is now private.
* Rename `X::OAuthAuthenticator` to `X::OAuth1Authenticator`
* Move the HTTP client into `x-core`, under `lib/x/core`, and the uploaders into `x-uploader`, under `lib/x/uploader`
* Wrap every network failure in `X::NetworkError`, so a stream of `x-streaming` reconnects after it
  * That is `IOError`, `SystemCallError`, `Timeout::Error`, `Net::ProtocolError`, and `Zlib::Error`.
  * It is also `Net::HTTPBadResponse`, `OpenSSL::SSL::SSLError`, and the `SocketError` of a host that cannot be resolved.
* Stop following redirects after exactly `max_redirects` hops, rather than one more
  * `max_redirects: 0` follows none, and raises `X::TooManyRedirects` for each redirect that could be followed.
* Sign OAuth 1.0a requests with the [simple_oauth](https://github.com/laserlemon/simple_oauth) gem, which sends the same header
* Build and parse the OAuth 2.0 token refresh with simple_oauth, which sends the same request
* Rename `X::OAuth2Authenticator#refresh_token!` to `#refresh!`, which returns the frozen `X::OAuth2Tokens` of the refresh
  * It returned the Hash of the token response.
  * It raises `X::UnsupportedOperation` for an authenticator that holds no refresh token.
* Raise `ArgumentError` from `X::Client.new` and `X::Client#with` for credentials that do not form a complete set
  * Such a client sent requests without credentials, or as the app when an access token lacked its secret.
  * A credential of no complete set, such as a `client_id` beside a `bearer_token`, raises rather than be ignored.
  * OAuth 2.0 credentials beside a complete set of OAuth 1.0a credentials raise.
  * An empty String credential, as `ENV.fetch("X_BEARER_TOKEN", "")` reads, or one that is not a String, raises.
  * `expires_at` raises beside anything but the OAuth 2.0 `client_id` and `access_token` it describes.
* Raise `ArgumentError` from an authenticator's constructor for a missing, empty, or non-String credential
  * An `expires_at` that is not a `Time`, such as a String read back from JSON, raises it too.
* Raise `X::InvalidResponse` for a successful response whose body is not JSON, such as a captive portal's page
  * It returned nil; a successful response without a body still returns nil.
  * `X::InvalidResponse` is an `X::HTTPError` whose `problem` is nil and whose `problems` are empty.
* Tag the body of a response UTF-8 rather than binary, so it no longer raises `Encoding::CompatibilityError`
  * That is the `body` of `X::Response`, `X::HTTPError`, and `X::InvalidResponse`, and each line of a stream.
  * A body that is not valid UTF-8 keeps its bytes, which `valid_encoding?` tells apart.
* Raise `X::AuthorizationError`, an `X::ClientError`, when X refuses to issue or refresh a token or to exchange a code
  * It replaces a bare `X::Error`, and holds the OAuth 2.0 `error_code` and the `status`, `headers`, and `body`.
  * It is not an `X::Unauthorized`, so code that asks the user to authorize the app again rescues both.
  * A 429, server error, redirect, or non-JSON answer from a token endpoint raises the `X::HTTPError` of that response.
  * A declined authorization raises `X::AuthorizationDenied`, an `X::Error` with the `error_code` of the redirect.
* Return nil from `X::TooManyRequests#reset_at`, `#reset_in`, and `#retry_after` for a response that names no reset time
  * They returned `Time.at(0)` and 0, which told a caller to retry at once.
* Make the connection of a client internal, as `X::Core::Connection`, in place of `X::Connection`
  * The authenticators take no `connection:`, since a client sends their token requests over its own.
  * `X::OAuth2Authorization` takes `base_url`, `proxy_url`, the timeouts, `debug_output`, and `headers` in place of `connection:`.
* Resolve an endpoint with a leading slash against the base URL, so `client.get("/users/me")` requests `/2/users/me`
  * Pass a whole URL to reach another path of the host.
* Raise `ArgumentError` from `get`, `post`, `put`, `delete`, and `get_stream` for an invalid endpoint, before any request
  * An endpoint that is not a String, such as a Symbol or a URI, raises it naming its class, rather than `NoMethodError`.
  * An invalid URL, or one that is not http or https with a host, raises it naming the endpoint and what is wrong.
  * It raised `URI::InvalidURIError`, or an `ArgumentError` of `Net::HTTP` that named no endpoint.
* Send each request once, turning off the retry `Net::HTTP` makes of a GET, PUT, or DELETE after a timeout or drop
  * That retry sent the OAuth 1.0a nonce and signature again, and could repeat a read the API bills.
  * Such a failure raises `X::NetworkError`, which `max_retries` sends again only for a request that never reached the API.
* Make the token endpoint of `X::OAuth2Authenticator` private, in place of the public `TOKEN_HOST` and `TOKEN_PATH`
* Report every rate limit a response names from `X::TooManyRequests#rate_limits`, not only the exhausted ones
  * `#rate_limit` reads the 15-minute limit, as on `X::Response`, rather than the exhausted one that resets last.
  * That exhausted limit, which `reset_at`, `reset_in`, and `retry_after` still wait for, is `#limiting_rate_limit`.
* Make `X::HTTPError::JSON_CONTENT_TYPE_REGEXP` and `X::OAuth2Authenticator::EXPIRATION_BUFFER` private
* Make `X::RateLimit.new` and `X::RateLimit.reported?` private
* Build the errors of `x-core` and `X::Response` with public constructors, so code that rescues one can be tested
  * `X::HTTPError.new(status:, headers:, body:, http_method: nil, uri: nil)`, or with `http_response:`, and a message first.
  * A status error such as `X::NotFound` needs neither, so `raise X::TooManyRequests, "slow down"` works.
  * `X::NetworkError`, `X::TooManyRedirects`, and `X::AuthorizationDenied` take a message, or none.
  * `X::Response.new(http_method:, uri:, status:, headers:, body:)` takes `http_response:` in their place too.
  * A response beside a status, a status outside 100 to 599, or headers that are not a Hash raise `ArgumentError`.
* Name the internals of `x-core` under `X::Core`, as private constants marked `@api private`, so they can change in 1.x
  * Among them are `RequestBuilder`, `RedirectHandler`, `Connection`, `ConnectionPool`, and the client's mixins.
  * The client, authenticators, `X::OAuth2Authorization`, `X::Response`, `X::RateLimit`, and errors keep their names.
  * The signatures `x-core` ships declare its public interface alone.
* Name the gem in the `User-Agent` of every request, token requests included, as `x-ruby/1.0.0 ruby/3.4.0 (arm64-darwin24)`, rather than `X-Client`
* Send an idempotent request again on a new connection when the kept-open connection it took had gone stale
  * That is an `EOFError`, `ECONNRESET`, `ECONNABORTED`, or `EPIPE` before the status and headers of its response are read.
  * A response cut off after that is never sent again, as the API answered it.
* Raise `X::NetworkError` for a body cut off before its end, or shorter than its `Content-Length`, rather than read what arrived
  * Any other failure, such as a timeout, is left to the retries of the client.
* Document every error class of `x-core` alike, and draw the whole hierarchy on `X::Error`
* Request the token endpoints at the origin of the client's base URL, rather than at `api.x.com` whatever the base URL
  * They keep the path the base URL serves the API at, minus a trailing API version, which was dropped.
  * Under `https://gateway.example/x/2/`, app-only tokens come from `/x/oauth2/token`, refreshes from `/x/2/oauth2/token`.
  * `X::OAuth2Authorization` exchanges its code at the origin of the base URL of the client it builds.
* Raise `ArgumentError` from `post` and `put` for a keyword they do not take, such as `client.post("tweets", text: "Hello")`
  * The message says to pass the body as a Hash: `post("tweets", {text: "Hello"})`.
* Keep the state of `X::Client` in an internal object, so no method another gem mixes in replaces one of its helpers

### Removed
* Remove `X::HTTPError#code`; read the Integer `#status`, or the String `error.http_response.code`
* Remove `X::HTTPError#error_message` and `#message_from_json_response`, and make `#json?` private
* Remove `X::OAuthAuthenticator::OAUTH_SIGNATURE_ALGORITHM`, `OAUTH_VERSION`, and `OAUTH_SIGNATURE_METHOD`
* Remove `X::OAuth2Authenticator::REFRESH_GRANT_TYPE`
* Remove the `base64` dependency of `x-core`
* Remove `X::RateLimit#retry_after`, an alias for `#reset_in`; read `#reset_in`
* Remove the setters of `X::RateLimit`, `X::BearerTokenAuthenticator`, `X::OAuth1Authenticator`, and `X::OAuth2Authenticator`
  * Derive a client that holds another credential with `X::Client#with`.
* Remove the setters of `X::Client`; derive a client that differs with `X::Client#with`
  * Gone: `api_key=`, `api_key_secret=`, `access_token=`, `access_token_secret=`, `bearer_token=`, and `client_id=`.
  * Gone: `client_secret=`, `refresh_token=`, `base_url=`, `default_array_class=`, `default_object_class=`, and `max_redirects=`.
  * Gone: `open_timeout=`, `read_timeout=`, `write_timeout=`, `proxy_url=`, and `debug_output=`.
* Remove the setters of `X::Connection`: `open_timeout=`, `read_timeout=`, `write_timeout=`, `proxy_url=`, and `debug_output=`
* Remove the proxy readers of `X::Connection`: `proxy_url`, `proxy_uri`, `proxy_host`, `proxy_port`, `proxy_user`, `proxy_pass`
* Remove `X::Connection::DEFAULT_HOST` and `DEFAULT_PORT`, since every request names its host
* Remove `X::OAuth1Authenticator#access_token`, a credential; `user_id` reads the user the token acts for

### Fixed
* Keep the method and body of a `PUT` or `DELETE` that a 301 or 302 redirects, as RFC 9110 has it
  * A `delete` that a 301 answered read the resource at the new location, and returned it as though deleted.
  * A `POST` that a 301 or 302 redirects, and any request a 303 redirects, is still followed with a `GET`.
* Declare `json`, `net-http`, and `uri` in `sig/manifest.yaml`, so `rbs collection` loads them for dependents
* Resolve a relative redirect against the URL of the request, not the base URL, so one from `upload.x.com` stays there
* Build the message of an `X::HTTPError` from a body that is not the JSON its content type claims
  * It raised `JSON::ParserError`, `KeyError`, or `TypeError` in place of the error, so a stream did not reconnect.
  * An error without a `message` gives its `detail` or `title`, once: `Unauthorized`, not `Unauthorized: Unauthorized`.
* Refresh an OAuth 2.0 token over the client's own connection, so its proxy, timeouts, and debug output apply
* Drop the credentials and any `Authorization`, `Cookie`, or `Proxy-Authorization` header on a redirect to another origin
  * A header named by a String, or by a Symbol such as `proxy_authorization:`, in any case, is dropped.
  * A 307 or 308, and a 301 or 302 of anything but a `POST`, still sends the request body to the new host.
* Send no `Authorization` header from a client without credentials, rather than an empty one
* Send a `Content-Type` header only with a request that carries a body
  * A body is sent as JSON unless the request's headers, or its `form:`, name another type.
  * A redirect followed with a `GET` sends no `Content-Type`.
* Raise `X::ClientError` or `X::ServerError`, rather than `X::HTTPError`, for a 4xx or 5xx no error class names
  * So a stream reconnects, and a chunk upload retries, after any server error, such as a 501.
* Link each gem's `changelog_uri` to the `main` branch rather than `master`
* Send the credentials of the authenticator on every redirected request, not only the first
* Sign a form-encoded request body with OAuth 1.0a, which the signature left out
* Sign every value of a query parameter that repeats, rather than only one of them
* Sign the normalized URL, so a request to a host with no path signs the `/` the server sees
* Form-encode the client credentials before Basic authentication on a token refresh, as RFC 6749 Section 2.3.1 requires
* Leave the user and password of a proxy out of the message of an invalid proxy URL, and out of `inspect`
  * A proxy URL that cannot be parsed raises `ArgumentError` rather than `URI::InvalidURIError`.
* Decode a percent-encoded proxy user and password, which were sent to the proxy still encoded
* Connect to an `https://` proxy over TLS, rather than send it the target host and credentials in plaintext
* Raise `X::HTTPError` for a redirect that cannot be followed, rather than `KeyError` or `URI::InvalidURIError`
  * That is a 300, 304, or 305, which was followed, or one whose `Location` is missing, invalid, or not HTTP or HTTPS.
  * Such a redirect raised `ArgumentError` too.
* End a `base_url` without a trailing slash with one, so `https://api.x.com/2` requests `/2/users/me`, not `/users/me`
* Raise an error of `on_response`, a request's block, or an `object_class` as it was raised, not as one of the request
  * Such an error is not sent again, waited out, or refreshed for, even an `X::ServerError` or an `X::Unauthorized`.
  * A stream stops on it rather than reconnect; a dropped socket or a line that is not JSON still reconnects.
* Send a query parameter without a value, as in `get("users?flag")`, as `flag` rather than `flag=`
  * An empty parameter, as between the `&&` of `"a=1&&b"`, is kept, where it was sent as `=`.
* Connect to a host, or a proxy, named by an IPv6 literal, such as a `base_url` of `http://[::1]:8080/`
  * `x-core` depends on net-http 0.8 or a later 0.x, since the net-http 0.6 of Ruby 3.4 cannot.
* Take the proxy from `https_proxy` for HTTPS and `http_proxy` for HTTP, and honor `no_proxy`, without a `proxy_url`
  * `Net::HTTP` read `http_proxy` alone, whatever the scheme.
* Declare `X::BadGateway` and `X::GatewayTimeout` as `X::ServerError`s in the signatures, as the classes always were

[1.0.0]: https://github.com/sferik/x-ruby/releases/tag/v1.0.0
