# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-18

See [UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) for the changes that code written for 0.19 needs.

### Added
* Split the gem into five gems released in lockstep: `x-core`, `x-uploads`, `x-streams`, `x-resources`, and `x`
  * `x-core` is the HTTP client and declares `X::Error`, the base of every error the gems raise
  * `x-uploads` uploads media, profile images, and banners; `x-streams` reads streams and filtered-stream rules
  * `x-resources` holds the resource objects and makes its requests through the client it is given
  * `x` depends on all four and mixes the object, upload, and streaming methods into `X::Client`
  * Every public class is named directly under `X`
  * `x` depends on exactly its own version of the other four; `x-uploads`, `x-streams`, and `x-resources` each depend on `x-core` with `>= 1.0.0, < 2`
* Add `X::Resources::Error`, `X::Uploads::Error`, and `X::Streams::Error` to rescue the failures of one gem alone
* Ship a `CHANGELOG.md` with `x-core`, `x-uploads`, `x-streams`, and `x-resources`, which each gemspec's `changelog_uri` names
* Publish the API documentation of every gem at https://sferik.github.io/x-ruby/api/, which the `documentation_uri` of `x` names
  * Each gem ships a `.yardopts`, so its documentation on rubydoc.info leaves out the private API
* Add `X.gem_version` and the `gem_version` of `X::Core`, `X::Uploads`, `X::Streams`, and `X::Resources`, each a `Gem::Version`
* Load `x-uploads` from `require "x"`, so `X::Uploads::MediaUpload` and `X::Uploads::Account` need no further require
* Add `X::Client#get_stream`, which sends a GET and yields an `X::StreamResponse` before its body is read
  * It reads the `status`, `headers`, and `rate_limit` of the response, and its body with `read_body`
  * `read_body` passes binary chunks to a block, or returns the whole body as a UTF-8 String, nil for a response without one
  * Sends the client's credentials, headers, timeouts, and proxy, and refreshes a rejected token as any request does
  * Asks for a body that is not compressed, which Net::HTTP would hold back in blocks, unless a header names another encoding
  * Raises the `X::HTTPError` of a failed response; otherwise returns what the block returns
  * `read_body` raises `X::NetworkError` for a socket error while reading the body, inside the block, which can rescue it
  * `read_body` reads the body once, inside the block: a second read, unless both read it whole, or one after the block returns, raises `X::Error`, which is not retried
  * A `dup` or `clone` of the response shares its reads, and a frozen response is read as any other
  * An error of the block reaches the caller as raised
  * `x-streams` reads the streams of the API with it
* Add `X::Client#with_retries`, `memoized`, and `memoize`, kept throughout 1.x for the gems that extend a client
  * `x-uploads` sends each chunk of an upload with `with_retries`; `x-resources` keeps the authenticated user with `memoize`
* Pass a block to `get`, `post`, `put`, and `delete` to receive the `X::Response` of each response the request gets
  * It is passed what `on_response` is passed, at the same points, refused responses and retries included
  * The client's `on_response` runs first
* Pass query parameters to `get`, `post`, `put`, `delete`, and `stream` as `params:`
  * nil values are dropped, Arrays are joined with commas, and a `Time` is sent in UTC as ISO 8601
* Encode a `post` or `put` body that is a Hash or an Array as JSON
  * A body that is not a String, a Hash, or an Array, such as an IO or a Symbol, raises `ArgumentError` before any request
* Send a form body with the `form:` of `post` and `put`, whose fields are encoded as `params:` are
  * Passing both a body and `form:` raises `ArgumentError`
* Add the `headers:` option of `X::Client.new`, headers sent with every request and stream of the client
  * A Hash of String or Symbol names to String values; anything else raises `ArgumentError` when the client is built
  * A header passed to a request or `get_stream` replaces the client's, which replaces the gem's default of that name
  * Names are case-insensitive, copies made with `with` keep them, and credential headers are dropped on a cross-origin redirect
  * `X::Client#headers` reads them back frozen, each named by the String it is sent with, as `{"user-agent" => ...}`
  * Token requests carry them too: the app-only token fetch, OAuth 2.0 refreshes, and the code exchange of `X::OAuth2Authorization`
  * The token request's own `Authorization`, `Content-Type`, and `Accept` win, and a client's `Authorization` header is never sent with one
* Pass an `X::Response` to the `on_response` of a client after every request, and for each object a stream delivers
  * `X::Response#resource_counts`, `rate_limits`, and `rate_limit` read the resources the response returned and the rate limits it reported
  * An `on_response` that is neither nil nor responds to `call` raises `ArgumentError` when the client is built
* Add `X::Response#headers` and `X::HTTPError#headers`, frozen Hashes with lowercase names and repeated fields comma-joined
  * Read each `Set-Cookie` with `http_response.get_fields("set-cookie")`
* Retry a request refused for a rate limit up to `max_rate_limit_retries` times (default 0)
  * It waits as long as the refusal asks, up to `max_rate_limit_wait` seconds (default 900), plus up to 5 seconds of jitter
  * A refusal that asks no wait and names no reset waits a minute, doubling for each retry after
  * A refusal for the usage cap of the project, which `X::Problem#usage_capped?` tells, raises at once
* Retry a failed request up to the `max_retries:` of `X::Client.new` (default 2; 0 raises at once)
  * A `GET`, `PUT`, or `DELETE` is retried after `X::ServerError`, `X::RequestTimeout`, or a network error before it was sent
  * The wait starts at up to a second and doubles, up to a minute, with jitter; a longer `Retry-After` is waited out
  * A `Retry-After` of more than a minute raises at once; a `POST` and any other 4xx are not retried for these, though a 429 and a rejected OAuth 2.0 token are, as the bullets on them say
  * An error raised by `on_response`, a request's block, or `from_response` is never retried
* Add the defaults of `X::Client` as constants: `DEFAULT_MAX_REDIRECTS`, `DEFAULT_MAX_RATE_LIMIT_RETRIES`, `DEFAULT_MAX_RATE_LIMIT_WAIT`, `DEFAULT_MAX_RETRIES`
  * `X::Client::DEFAULT_OPEN_TIMEOUT`, `DEFAULT_READ_TIMEOUT`, `DEFAULT_WRITE_TIMEOUT`, and `DEFAULT_KEEP_ALIVE_TIMEOUT` replace those of `X::Connection`
  * `X::StreamingClient::DEFAULT_MAX_RECONNECTS` sits beside its `DEFAULT_READ_TIMEOUT`
* Keep up to 16 idle connections open per host between requests, for `keep_alive_timeout` seconds (default 30)
  * `keep_alive_timeout` is a setting of `X::Client` and `X::OAuth2Authorization`
  * Copies made with `with` that connect the same way share the client's connections
  * `X::Client#close` closes them, and those of the copies that share them; a later request opens one again
* Copy a client with some options changed with `X::Client#with`, which takes the options of `X::Client.new`
  * e.g. `client.with(base_url: "https://api.x.com/1.1/")`, or `client.with(access_token: nil, access_token_secret: nil)` for app-only
  * A copy given no new credentials shares the client's authenticator, and so its fetched or refreshed tokens
  * A copy that shares an OAuth 2.0 authenticator raises `ArgumentError` for an `expires_at`
  * A copy with other credentials holds `refresh_token`, `expires_at`, `scopes`, `save_tokens`, and `load_tokens` only when given them
  * `X::Client#expires_at` reads the expiration of the last refresh
* Authenticate a client with an authenticator built elsewhere, given as the `authenticator:` of `X::Client.new` or `with`
  * Raises `ArgumentError` beside credentials or an `expires_at`, or for anything that is not an `X::Authenticator`
  * A custom authenticator subclasses `X::Authenticator` and overrides its public `headers`
  * `headers` is passed a request answering `http_method`, `uri`, `body`, and `[]`, typed as `X::_AuthenticatorRequest`
  * The refreshes of a shared `X::OAuth2Authenticator` reach the `save_tokens` of every client that uses it
  * A client given an `X::OAuth2Authenticator` holds no app credentials, so its `app_only` raises `X::UnsupportedOperation`
* Add `X::Client#app_only`, a copy of a client that authenticates as the app
  * It sends the client's bearer token, or one it fetches once with the API key and secret, shared with copies
  * It raises `X::UnsupportedOperation` for an OAuth 2.0 user client that holds no bearer token, API key, or secret
* Authenticate as the app given an `api_key` and `api_key_secret` without access tokens, through `X::AppOnlyAuthenticator`
  * It fetches a bearer token on the first request, and fetches another and resends once when the API answers 401
* Refresh an OAuth 2.0 access token when it expires, given the `expires_at:` (a `Time`) of `X::Client`, or when the API answers 401
  * The request is sent again with the new token; a token refreshed less than a minute ago is not refreshed again
  * A 401 from another origin refreshes nothing
* Store the tokens of each OAuth 2.0 refresh with the `save_tokens:` of `X::Client.new`, a callable passed an `X::OAuth2Tokens`
  * It is called once the refresh releases its lock, in order, skipping a refresh another has replaced
  * If a hook raises, the others still run, then `X::TokenReportFailed` is raised, holding the `tokens` and `client`
  * So does a `Timeout::Error` a hook raises, even one `Timeout.timeout(5, Timeout::Error)` raises around the request
  * A `save_tokens` that does not respond to `call` raises `ArgumentError` when the client is built
  * An authenticator built by hand reports its refreshes to no hook of its own, only to those of the clients it is given to
* Add `X::OAuth2Tokens`, the frozen `access_token`, `refresh_token`, `expires_at`, and `scopes` of a refresh or code exchange
  * `as_json`/`to_json` write it, and `X::OAuth2Tokens.from_json` reads it back, with String or Symbol keys
  * It marshals, and writes YAML, in a versioned format every 1.x release reads
  * `X::OAuth2Tokens.new` raises `ArgumentError` for an empty or non-String token or an `expires_at` that is not a `Time`
* Share a user's tokens among processes with `load_tokens:`, a callable that returns the stored `X::OAuth2Tokens` or nil
  * Taken by `X::Client.new`, `X::Client#with`, `X::OAuth2Authorization#client`, and `X::OAuth2Authenticator.new`
  * A refresh reads the store first and takes newer tokens there rather than spend its own refresh token
  * A refresh refused with `invalid_request` or `invalid_grant` reads the store again before raising
  * One that does not respond to `call` raises `ArgumentError`; one that returns anything else raises `TypeError`
* Read the scopes X granted an OAuth 2.0 token with `scopes` on `X::OAuth2Tokens`, `X::OAuth2Authenticator`, and `X::Client`
  * A frozen Array of Strings, or nil when not known
  * `X::Client.new`, `with`, and `X::OAuth2Authenticator.new` take `scopes:`, so `X::Client.new(client_id:, **tokens.to_h)` works
  * Scopes that are not an Array of scope names, or given beside other than OAuth 2.0 credentials, raise `ArgumentError`
* Authorize an app with the OAuth 2.0 authorization code flow and PKCE with `X::OAuth2Authorization`
  * It builds the authorization URL, and exchanges the code of the redirect for `tokens` or a `client`
  * The tokens hold no app credentials; build a client as `X::Client.new(client_id:, client_secret:, **tokens.to_h)`
  * It raises `X::AuthorizationDenied` when the user declines, the state does not match, or the redirect is invalid
  * It raises `X::AuthorizationError` when X refuses the code, and `ArgumentError` for a state, client ID, or redirect URI that is nil, empty, or not a String
  * `client` checks its options before spending the code, and passes the first tokens to its `save_tokens`
  * It takes `headers:`, which the code is exchanged with and the client it builds is given, as a gateway may require
* Refresh the tokens of a public OAuth 2.0 client, given a `client_id`, `access_token`, and `refresh_token` without a `client_secret`
* Authenticate with an OAuth 2.0 access token that is not refreshed, given a `client_id` and `access_token` without a `refresh_token`
  * An access token the API rejects raises `X::Unauthorized`, and `refresh!` raises `X::UnsupportedOperation`
* Add `X::Authenticator#user_id`, the user an OAuth 1.0a access token acts for, or nil
* Add `inspect` to `X::Client` and the authenticators that never reveals credentials
* Add `X::HTTPError#status`, `body`, `problems`, and `problem`, and `http_response`, an escape hatch for the transport's response
  * It is a `Net::HTTPResponse` today, and its class is not part of what 1.x promises
  * `status` is an Integer, as `X::Response#status` is
  * `problem` is the problem the body describes, or else the first error it names
* Add `X::Problem`, what the API said of a request, answered by `X::HTTPError#problem` and reported by `x-resources`
  * Reads `title`, `detail`, `type`, `resource_type`, `resource_id`, `parameter`, `value`, and `message`
  * `about?` tells whether it names a resource, or an Integer or String identifier, comparing them as Strings
  * Equals a problem of the same attributes, writes JSON with `as_json`/`to_json`, and marshals in a versioned format
* Add `X::UnsupportedFormat`, an `X::Error` raised when reading back a Marshal, YAML, or JSON format a release does not read
* Raise `X::PaymentRequired` (402), `X::MethodNotAllowed` (405), `X::RequestTimeout` (408), `X::UnsupportedMediaType` (415), and `X::UnavailableForLegalReasons` (451)
  * Each is an `X::ClientError`; X sends 402 when the account that pays for the app has no credit left
* Name the request an error was raised for: `X::HTTPError`, `X::NetworkError`, `X::InvalidResponse`, and `X::TooManyRedirects` read `http_method` and `uri`
  * The message names it without its query, as `GET /2/users/1: Could not find user`
  * A redirected request is named by the last request sent
* Add `X::InvalidResponse#body`, `status`, and `headers` for a successful response that is not JSON
  * `body` falls back to the body of the response once it has been read whole, and never reads a stream
* Add `X::TooManyRequests#exhausted_rate_limits` and `#limiting_rate_limit`
* Add `X::UnsupportedOperation`, an `X::Error` declared by `x-core`, raised for anything the API offers no way to do
  * e.g. hydrating or refreshing an `X::Poll` or an `X::Place` that is not hydrated, as in "X::Poll cannot be fetched by id"
  * A finder the API lacks is not defined: `X::Poll` and `X::Place` answer none, `X::List`, `X::Community`, and `X::DirectMessage` only `find` and `find!`
* Add the upload methods to `X::Client`: `upload_media`, `chunked_upload_media`, `await_media_processing`, and `await_media_processing!`
  * And `add_alt_text`, `add_subtitles`, `update_profile_image`, and `update_profile_banner`, each calling an uploader with the client
  * As in `client.create_post("Look", media_ids: [client.upload_media("cat.jpg")])`
  * `chunked_upload_media` returns the `X::UploadedMedia` once it is finalized, without waiting for processing
  * `await_media_processing!` raises if processing failed, where `await_media_processing` returns the status
  * Media that already says its processing ended, or an image's upload response, is returned without a request
  * They come from `X::Uploads::API`, which code using `x-core` and `x-uploads` alone can include; a `client:` option raises `ArgumentError`
* Return an `X::UploadedMedia` in place of a Hash from the uploaders and their client methods
  * From `upload`, `chunked_upload`, `await_processing`, `await_processing!`, `add_alt_text`, and `add_subtitles`
  * It reads `id` and `media_id` (Integers), `media_key`, `bytesize`, `expires_after_secs`, `processing_info`, `state`, and `check_after_secs`
  * It tells `processing?`, `failed?`, and `ready?`, and still reads as a Hash with `[]`, `fetch`, `dig`, `key?`, and `to_h`
  * It is frozen, writes `as_json`/`to_json`, and marshals in a versioned format; one without an `"id"` of 1 to 19 digits raises `ArgumentError`
  * `add_alt_text` and `add_subtitles` return the media they describe, ready to attach to a post
* Infer the media category of an upload from the bytes the media begins with, or else its extension, so `upload` takes any file
  * Videos and large GIFs upload in chunks, and `upload` waits for X to process them
  * `upload` takes `media_type:`, `chunk_size:`, and `concurrency:`, and raises `ArgumentError` for any other unknown keyword
* Take the media as the positional argument of the `X::Uploads::MediaUpload` and `X::Uploads::Account` methods, with `client:` as a keyword
* Describe uploaded media with the `alt_text:` of `X::Uploads::MediaUpload.upload` or with `X::Uploads::Metadata.add_alt_text`
  * Alt text that is not a String, not convertible to UTF-8, empty, or over 1,000 characters raises `ArgumentError` before a request
  * It is sent again after a server or network error
  * An upload that cannot add its alt text raises `X::AltTextFailed`, which holds the uploaded `media`, for any `StandardError` but a `Timeout::Error` or an `X::TokenReportFailed`, which are raised as they are, as an interrupt is, but a timeout raised with its class, as by `Timeout.timeout(5, Timeout::Error)`, that lands in `save_tokens` is an `X::TokenReportFailed`, holding the tokens
* Attach uploaded subtitles to a video with `X::Uploads::Metadata.add_subtitles`
  * `media_category:` defaults to `"tweet_video"`, and takes `"amplify_video"` in any case, or `TweetVideo`/`AmplifyVideo`
  * Any other category raises `ArgumentError`
  * It is sent again after a server or network error
* Share uploaded media, or give it other owners, with the `shared:` and `additional_owners:` of `upload`, `chunked_upload`, and `upload_media`
  * Media given `shared: true` uploads in chunks; an image of unknown type, such as HEIC, given an image `media_category:` is sent as JPEG
  * A `shared` other than true, false, or nil, or `additional_owners` that are not user IDs, raise `ArgumentError`
* Add `X::Uploads::MediaUpload::DEFAULT_CONCURRENCY` (4) and `MAX_CONCURRENCY` (16), the chunks a chunked upload sends at once
* Add `X::Uploads::MediaUpload::DEFAULT_PROCESSING_TIMEOUT` (600 seconds) and `AMPLIFY_VIDEO`, beside `TWEET_VIDEO`
* Name the media category of an upload with a Symbol, in any case, as in `media_category: :tweet_video`
* Rescue the errors `x-uploads` raises of its own with `X::Uploads::Error`
  * It is the base of `X::AltTextFailed`, `X::ChunkedUploadFailed`, `X::InvalidMedia`, and `X::MissingMediaData`
  * And of `X::MediaProcessingCheckFailed`, `X::MediaProcessingFailed`, and `X::MediaProcessingTimeout`
  * `X::InvalidMediaType`, an `X::InvalidMedia`, is raised for media of a type the API does not take
  * A bad category, chunk size, concurrency, alt text, or processing timeout raises `ArgumentError` instead
  * Each error that holds media takes an optional message and `media:`; `X::MediaProcessingTimeout` takes `timeout:` too
* Raise `X::MediaProcessingCheckFailed`, which holds the uploaded `media`, when a check of its processing fails
* Raise `X::ChunkedUploadFailed`, which holds the initialized `media`, when a chunk or the finalize fails
  * Such as a server error, a file deleted, closed, or shrunk mid-upload, or a finalize response without media
  * It and `X::MediaProcessingCheckFailed` are raised for any `StandardError`, as the `cause`, such as one `on_response` raises
  * A `Timeout::Error`, an `X::MediaProcessingTimeout`, or an interrupt is raised as it is, but one raised with its class, as by `Timeout.timeout(5, Timeout::Error)`, that lands in `save_tokens` is an `X::TokenReportFailed`, holding the tokens
  * An `X::TokenReportFailed` is raised as it is too, from a chunk, the finalize, or a check, so `rescue X::TokenReportFailed` stores its `tokens`
* Take an upload's result, a media ID, a media key, or anything that answers `media_key` in `await_processing`, `await_processing!`, `add_alt_text`, and `add_subtitles`
  * Anything else, or an ID that is not 1 to 19 digits, raises `ArgumentError` before a request
  * The signatures type what answers `media_key` as `X::Uploads::_MediaKeyed`
* Upload a GIF with a single frame as an image, since X fails to process it as a GIF
* Stream with `X::StreamingClient`, which `X::Client#streaming` builds with the client's credentials, base URL, classes, and `on_response`
  * `streaming` takes `read_timeout:`, `max_reconnects:`, and `on_reconnect:`; other settings come from a copy, as `client.with(open_timeout: 2).streaming`
  * `stream` raises `ArgumentError` when given no block, before it opens the stream
* Stop the streams of a streaming client from any thread, or the trap of a signal, with `X::StreamingClient#stop`
  * Each stream stops the next time it waits on the API, at once if idle or waiting to reconnect
  * A stream a Fiber scheduler runs, as in an `Async` task, stops once its block next returns, at the next keep-alive, or within a second as it waits to reconnect
  * A stopped streaming client stays stopped: a stream asked of it later returns nil at once, without a request
  * Each stopped `stream` call returns nil, `stop` returns nil, and `stopped?` tells a stopped streaming client
  * A block, `on_response`, or `on_reconnect` running at that moment runs to its end first
  * `streaming` builds a new streaming client each time, so keep the one you stop in a variable
* Stop a stream from its block: `break` stops it and returns its value, and `throw` unwinds past it
  * An error of the block, `on_response`, or the object class stops it and reaches the caller, `StopIteration` included
* Read and change the rules of the filtered stream with `rules`, `add_rules`, and `delete_rules` on `X::StreamingClient`
  * A rule is a frozen `X::StreamRule` of its `value`, `tag`, and `id` (an Integer, or nil for a rule to add)
  * An `id` is an Integer that is not negative or a String of digits alone; anything else raises `ArgumentError`
  * Add an `X::StreamRule`, a Hash of `value` and `tag`, or a String; delete by rule, `id`, or value
  * An `X::MatchingRule` deletes the rule it names, so `delete_rules(post.matching_rules)` deletes the rules a post matched
  * Anything else, such as a post, raises `ArgumentError` before a request
  * `dry_run: true` checks the rules and changes none; `rules` takes `params:` and reads every page
  * The problems the API reports of rules it does not add or delete are yielded as `X::Problem`s, or without a block raise `X::RulesRejected`
  * A rule the app already has raises nothing, and is not among the rules `add_rules` returns, which are those it added; a block is still yielded its `DuplicateRule` problem
  * A rule X rejects, such as an invalid one, may keep it from adding any, and it reports that one alone; the rules returned say which were added
  * `X::RulesRejected#added` and `#deleted_count` hold what was done; no rules send no request
* Stream, and read and change stream rules, as the app from a client that signs with OAuth 1.0a, which the stream endpoints refuse
  * A client of an OAuth 2.0 user without app credentials streams as the user, so X's 403 raises `X::Forbidden`
* Reconnect a stream that ends, drops, or sends a line that is not JSON, backing off as X recommends
  * Up to the `max_reconnects` of the streaming client in a row (unlimited by default), reset by an object or keep-alive read from a connection open for a minute
  * So a stream whose connections each deliver something and drop backs off, and runs out of reconnects
  * Then it raises the last error: `X::NetworkError` for a stream that ended or dropped, `X::InvalidResponse` for a non-JSON line
  * A rate limit backs off from a minute, doubling, but raises `X::TooManyRequests` past `max_rate_limit_wait` or for the usage cap
  * A server error, 408, or 409 backs off from 5 seconds, up to 320 seconds, or waits longer for its `Retry-After`
  * A `Retry-After` past `max_rate_limit_wait` raises the error at once
  * What arrived of a line the stream ended within is dropped, unparsed and unreported, and the stream reconnects as one that ended
  * An error `on_response` raises for a failed response stops the stream and reaches the caller, as one for an object does
  * A certificate that does not verify raises its `X::NetworkError` at once, since it would not verify on the next attempt
* Report each reconnect of a stream to `on_reconnect:`, a callable passed the error and the seconds it waits
  * It is passed an error every time, never nil, and is called with those two arguments and no others throughout 1.x
  * It can call `stop` to give up, as on a host that never resolves, and the stream returns nil
  * An error it raises stops the stream and reaches the caller
* Read a stream with the `read_timeout` of the streaming client, 30 seconds by default, so a quiet stream reconnects
* Raise `X::StreamError`, an `X::Streams::Error`, for a stream line that holds errors and no data
  * It holds the `problems`, `http_method`, and `uri`; `on_response` is passed the line first
  * A line of `operational-disconnect`s alone, which `X::Problem#disconnect?` tells, reconnects; other problems stop the stream
* Add immutable, thread-safe resource classes, which descend from `X::Resource`
  * `X::User`, `X::Post` (aliased `X::Tweet`), `X::List`, `X::DirectMessage`, `X::Space`, `X::Media`, `X::Poll`, `X::Place`, and `X::Community`
  * Lists of resources or identifiers are frozen Arrays; copy one to change it
  * A list the response omits, such as `post.urls`, reads as an empty Array; `user.connection_status` reads nil unless requested
  * Text reads as the API sends it, so `post.text` and `direct_message.text` hold `&amp;`, `&lt;`, and `&gt;` throughout 1.x
  * Nested data, such as `post.entities` and `post.public_metrics`, reads as frozen Hashes keyed by String throughout 1.x
  * Nested data the API sends as anything but an object, or a list of them, raises `X::InvalidAttribute`
* Rescue the failures of the object layer with `X::Resources::Error`
  * It is the base of `X::MissingResource`, `X::UnreadableResponse`, `X::InvalidAttribute`, `X::MissingClient`, and `X::PageLimitReached`
* Include the object methods in a class of your own with `X::Resources::API`
  * The class answers `get`, `post`, `put`, and `delete` as `X::Resources::_Client` types them, taking keywords it does not read
  * The other modules and constants of `X::Resources` are private
* Compare resources by class and ID with `==`, `eql?`, and `hash`, so the same resource from different requests is equal
* Resolve references such as `post.author` and `post.replied_to` to included objects or ID stubs, one object per resource in a response
* Add `hydrate`, which fetches and memoizes the full resource, and `refresh`, which fetches it again
  * A resource fetched with fewer than the default fields or expansions is not hydrated; one fetched with more is
  * A resource without a client, such as one read back with `Marshal`, raises `X::MissingClient` from any request
  * `FIELDS` and `EXPANSIONS` may grow in a minor release; add to `default_params` rather than list every value
* Hydrate the stubs of a page of `stubs`, or of a cursor that requests identifiers alone, together, in batch lookups of up to 100
  * Lists, communities, and direct messages hydrate one at a time, as does a reference a page did not include; `hydrate_all` batches any
* Refer to a resource without a request with `X::User.from_id` and its equivalents, and tell such stubs apart with `stub?`
* Add `X::Cursor`, an `Enumerable` collection that fetches pages lazily at the maximum page size and caches them
  * `refresh` and `prefetch` fetch pages again or ahead
  * A page a prefetch failed to fetch raises the prefetch's error once it is reached, rather than be requested again
  * A page that names as its next a token already read raises `X::UnreadableResponse`
  * `page` takes an Integer index, raising `TypeError` for any other and `ArgumentError` for a negative one
  * `X::Cursor.new` is private; cursors come from the collections, searches, and lookups
* Answer `X::Cursor#first`, `take`, `any?`, `none?`, `one?`, and `empty?` from as few resources as they need
  * They read from pages already fetched, and request a page no larger than needed, raised to the endpoint's minimum
  * So `any?`, `none?`, and `empty?` request one resource and `one?` two, or the 5 or 10 an endpoint such as a search takes at least
  * A count that is not an Integer is converted as `Array#first` does; a String, or nil to `take`, raises `TypeError`
* Count a collection without paging it with `X::Cursor#published_count`, the number the API publishes
  * Followers, followed users, and list memberships of a user, and members and followers of a list; nil for others
* Read a collection a page at a time with `X::Cursor#each_page`, yielding `X::Page`s
  * A page holds `items`, `meta`, `result_count`, `next_token`, `previous_token`, and `problems`, and reads like an Array
  * `X::Page.new` raises `ArgumentError` for problems that are not `X::Problem`s
* Request identifiers alone from a cursor with `ids`, as in `user.followers.ids`, and scan stubs with `stubs`
* Type-check the resources of a collection: `X::Cursor` and `X::Page` are generic in their signatures
* Read the collections of a resource as cursors
  * A user's `followers`, `following`, `affiliates`, `posts`, `mentions`, `liked_posts`, `owned_lists`, `list_memberships`, and `followed_lists`
  * A list's `members`, `followers`, and `posts`, a post's `quotes`, and a space's `posts`, and its `buyers` (OAuth 2.0 user only)
* Add `home_timeline`, `blocking`, and `muting` cursors to `X::User`
* Read the authenticated user's reposted posts with `reposts_of_me` on the client and `X::Post`, aliased as `retweets_of_me`
* Tell a post that replies, quotes, or reposts with `reply?`, `quote?`, and `repost?`, and read its target with `replied_to`, `quoted`, and `reposted`
* Add `X::Post#liked_by`, `reposted_by`, and `reposts`, and `references` on posts and direct messages
* Look up users and posts by ID in parallel batches of 100 with `X::User.find_all` and `X::Post.find_all`
  * They return one resource per ID found, in the order asked, an ID given twice coming back twice
  * Once a batch fails, no further batch is sent and its error is raised
* Say how many batches a lookup requests at once with `concurrency:` (default 4)
  * Taken by `find_all`, `find_all_by_username`, `hydrate_all`, and `X::Space.find_all_by_creator`
  * And by `find_all_users`, `find_all_users_by_username`, `find_all_posts`, `find_all_spaces`, `find_all_media`, and `find_all_spaces_by_creator`
  * Anything but an Integer of at least 1 raises `ArgumentError`
* Hydrate many resources in parallel batches with `hydrate_all` on `X::User`, `X::Post`, `X::Space`, and `X::Media`
  * It drops nil and resources not found, skips hydrated ones, and stores what it found in each resource
  * A resource of another class raises `ArgumentError` before a request
* Add lookup, search, and action methods for the resources to `X::Client`
  * `find_user`, `find_all_users`, `current_user!`, `find_post`, `find_all_posts`, `find_list`, and `find_space`
  * `search_posts`, `search_all_posts`, `create_post`, `delete_post`, `direct_messages`, and `create_direct_message`
  * `follow`, `unfollow`, `like`, `unlike`, `repost`, and `unrepost`
  * The finders have `find_tweet` aliases
  * Actions return true or false; `follow` returns true once it has asked to follow a protected user
* Look up a mix of IDs and usernames with `find_all_users`, and usernames alone, even all-digit ones, with `find_all_users_by_username`
* Look up a user by ID when given an Integer and by username when given a String
  * Say which with `X::User.find_by_username`, `find_by_username!`, `find_all_by_username`, `find_by_id`, `find_by_id!`, and `find_all_by_id`
  * Or on the client with `find_user_by_username`, `find_user_by_username!`, `find_all_users_by_username`, `find_user_by_id`, `find_user_by_id!`, and `find_all_users_by_id`
  * Elsewhere, such as `follow` or `find_post`, an ID that is not a number raises `ArgumentError`
  * So does a resource of another class, as `client.like(user)`, or any other object that answers `id`
* Accept a username with a leading `@` in `find_user`, `find_all_users`, and `X::User.find_all_by_username`
* Search users with `X::User.search` and `client.search_users`
* Request the largest page each search allows: 500 posts from `search_all_posts` (100 with context annotations), and 1,000 users from `search_users`
* Look up direct messages with `find_direct_message`, many spaces with `find_all_spaces`, and a conversation with `direct_messages_with`
* Look up the spaces of many creators with `X::Space.find_all_by_creator` and `find_all_spaces_by_creator`, in batches of 100
* Search spaces with `X::Space.search` and `search_spaces` on the client, a cursor over live or scheduled spaces
* Look up and search spaces, and read their posts, whatever the client authenticates with
  * An OAuth 1.0a client, which the space endpoints refuse, requests them as the app; an OAuth 2.0 user client as the user unless it holds app credentials, when it too requests them as the app
* Read the topics of a space with `X::Space#topics`, each an `X::Topic` with a `name` and `description`
* Look up media by media key with `X::Media.find`, `find!`, and `find_all`, and `find_media`, `find_media!`, and `find_all_media`
  * Each takes a media key, media, or an upload's result; a numeric media ID raises `ArgumentError`
* Read the numeric ID of media with `X::Media#media_id`, as `X::UploadedMedia#media_id` reads it; `X::Media#id` is the media key
* Add `X::Community`, with `find_community`, `find_community!`, `search_communities`, `post.community`, and the `community:` of `create_post`
* Alias every client method named for direct messages with `dm`: `find_dm`, `find_dm!`, `dms`, `dms_with`, `dms_in`, `create_dm`, `create_group_dm`, `create_dm_in`, and `delete_dm`
* Raise `X::MissingResource`, an `X::Resources::Error`, from `current_user!`, `X::User.current!`, `find!`, and the bang finders of the client
  * `find_user!`, `find_user_by_username!`, `find_post!`, `find_list!`, `find_space!`, `find_media!`, `find_community!`, and `find_direct_message!`
  * The message names what was looked up, as "Could not find X::User @sferik"; `problems` explains why
  * It is not `X::NotFound`: a missing resource gives nil or `X::MissingResource` whether X answers 200 OK with no data or a 404 that reports the resource as not found
  * The `X::NotFound` of such a 404 is its `cause`; any other 404, such as one from a client pointed at the wrong host or API version, or one to `current_user` or a `find_all_…`, raises `X::NotFound`
* Add `current_user` and `current_user!` to the client, as `X::User.current` and `.current!`; `current_user` returns nil if the API answers without a user
* Take the authenticated user's ID from an OAuth 1.0a access token with `current_user_id`, without a request
* Name the interface after posts: `post_count`, `pinned_post_id`, `most_recent_post_id`, `edit_history_post_ids`, `note_post`, `referenced_posts`, and `repost_count`
  * The tweet-named methods, such as `create_tweet`, `tweets`, and `retweet_count`, remain as aliases
  * A response that names fields after tweets, as a stream does, is still read
* Request fields and expansions by the names the X API documentation gives, such as `post.fields` and `referenced_posts`
* Request no `edit_history_post_ids` or `entities.mentions.username` expansion, which the object layer never reads
* Read the IDs of users, posts, lists, direct messages, communities, and polls, and the attributes that refer to them, as Integers
  * The IDs of spaces, places, and media, media keys, `dm_conversation_id`, and usernames are Strings
  * `X::Problem#resource_id` and `#value` are Strings, so match a problem to a resource with `problem.about?(user)`
* Raise `X::MissingResource`, holding the response's problems, when a request that creates a resource is answered without it
  * From `X::Post.create`, `X::List.create`, `X::DirectMessage.create`, `create_group`, `create_in`, and their client methods
  * So `create_post`, `create_list`, `create_dm`, and the rest never return nil
  * A response whose data names no identifier raises it too
* Build the `reply`, `media`, and quote of a new post with the `reply_to:`, `media_ids:`, and `quote:` of `create_post` and `X::Post.create`
  * A field passed with a String key, such as `"reply"` or `"attachments"`, is read as its Symbol, so it is sent once
* Take an upload's result, media, or a media key in the `media_ids:` of `create_post`, reading its media ID
  * An ID that is not 1 to 19 digits, or anything else, raises `ArgumentError` before the request
* Post media without text: the text of `create_post`, `create_direct_message`, and their equivalents is optional
  * A post or message with neither text nor any other field raises `ArgumentError`
* Attach uploaded media to a direct message with `media_ids:`
  * Passing both `media_ids:` and `attachments:` raises `ArgumentError`; an empty `media_ids:` attaches nothing
* Start a group conversation with `X::DirectMessage.create_group` and `create_group_direct_message`, aliased `create_group_dm`
* Send to and read any conversation with `X::DirectMessage.create_in` and `.in`, and `create_direct_message_in` and `direct_messages_in`
  * The client methods have `create_dm_in` and `dms_in` aliases
* Add `X::DirectMessage.delete`, `message.delete`, and `delete_direct_message` on the client
* Add `X::DirectMessage#peer(user)`, the other participant of a one-to-one conversation, nil for a group conversation
* Add `X::DirectMessage#from?`, false for a message that does not name its sender
* Add `X::Post#coordinates`, and `permalink` and `uri`, the x.com address of a post, user, list, or community
* Add `X::Post#urls` and `X::Post#expanded_text`, the text with each shortened link expanded, every link in one pass
  * `expanded_text` HTML-escapes each URL it puts in, so the whole text reads escaped, as `text` does
* Read the full text of a post longer than 280 characters with `X::Post#text`, from its `note_post`
  * `entities` and `urls` of a long post read from the note alone
* Add `X::Post#matching_rules`, the filtered-stream rules a post matched, each a frozen `X::MatchingRule` with an `id` and `tag`
  * Building one whose `id` is not a String of digits or a non-negative Integer raises `ArgumentError`; `post.matching_rules` raises `X::InvalidAttribute` for one
* Add `X::User#profile_banner_url`, `parody?`, `identity_verified?`, `subscription_type`, `verified_followers_count`, `subscriber_count`, and `media_count`
* Add `X::User#receives_your_dm?`, `subscribes_to_you?`, and `subscription`; the predicates are false, and `subscription` nil, unless `user.fields` names them
* Add `X::Post#media_source_posts`, aliased `media_source_tweets`, the posts its attached media was first posted with
  * Resolved from the `attachments.media_source_tweet` expansion, which lookups request
* Add `X::Post#display_text_range`, an exclusive `Range`, nil when absent, and `scopes`, `card_uri`, `article`, `article_title`, `media_metadata`, and `paid_partnership?`, and `X::DirectMessage#entities`
* Add `X::User#affiliation`, `affiliated_with_ids`, and `affiliated_with`; a user included in another resource holds none until hydrated
* Read `is_identity_verified` and `is_ticketed` as `X::User#identity_verified` and `X::Space#ticketed`, with `?` predicates
* Match resources against `case/in` patterns with `deconstruct_keys`, as in `post in {like_count: 100..}`
  * Tweet-named aliases match too, as in `user in {pinned_tweet_id: Integer}`
  * `X::Trend`, `X::PersonalizedTrend`, and `X::PostUsage` match by their readers
* Write a resource, problem, trend, usage, matching rule, or page as JSON with `as_json` and `to_json`, never with credentials
  * Each marshals, and writes YAML, in a versioned format every 1.x release reads, coming back frozen
  * A resource keeps the included objects it refers to, but not its client
  * Read each but a page as a Hash with `to_h`
  * A cursor raises `X::UnsupportedOperation` from `as_json`, `to_json`, and `to_h`, and `TypeError` from `Marshal.dump`; serialize `to_a`
* Report the partial errors of a successful response as `X::Problem`s
  * `problems` on a resource holds those about it, the resources it refers to directly, or no identifier
  * `problems` on a page holds every problem of its response; a finder's block receives each one
* Count posts matching a query with `X::Post.count`, `count_all`, `count_by_period`, and `count_all_by_period`
  * On the client as `count_posts`, `count_all_posts`, `count_posts_by_period`, and `count_all_posts_by_period`, with tweet-named aliases
  * Counts by period are keyed by the `Range` of `Time` each period spans
  * A count that is not a String of digits or a non-negative Integer raises `X::InvalidAttribute`
  * An OAuth 1.0a client counts as the app; an OAuth 2.0 user client without app credentials counts as the user
* Report the post usage of the app's project with `X::PostUsage.current` and `client.post_usage`
  * They return nil, yielding the response's problems to a block, when it holds no usage
  * `X::PostUsage.current!` and `client.post_usage!` raise `X::MissingResource` instead
  * Includes its monthly cap, reset day, and usage by day and by app
* Read the trends of a place with `X::Trend.at` and `trends` on the client, given its WOEID, such as 1 for the world
  * An ID that is not a number raises `ArgumentError`; `max_trends` limits the 50 returned
  * An `X::Trend` reads its `name` and `post_count`; an OAuth 1.0a client requests trends as the app
* Read the trends X picks for the authenticated user with `X::PersonalizedTrend.all` and `personalized_trends`
  * An `X::PersonalizedTrend` reads its `name`, `category`, `post_count_text`, and `trending_since_text`
* Bookmark a post and remove the bookmark with `bookmark` and `unbookmark` on `X::Client`
* Read bookmark folders with `X::User#bookmark_folders`, a cursor of `X::BookmarkFolder`, and a folder's posts with `bookmarks(folder:)`
* Add `block`, `unblock`, `mute`, and `unmute` to `X::Client`
* Add `X::List.create`, `.update`, `.delete`, `list.add_member`, `remove_member`, `update`, and `delete`, with client equivalents
  * `create_list`, `update_list`, `delete_list`, `add_list_member`, and `remove_list_member`
  * An update with no field to change raises `ArgumentError` before a request
* Follow, unfollow, pin, and unpin a list with `follow_list`, `unfollow_list`, `pin_list`, and `unpin_list` on `X::Client`, and read `X::User#pinned_lists`
* Hide and show a reply with `X::Post#hide_reply` and `#unhide_reply`, their class methods, and the client's `hide_reply` and `unhide_reply`
* Check whether a user follows another with `user.follows?`, and a list's membership with `list.member?`, without fetching every page
  * `follows?` looks up `connection_status` once when either user is the authenticated user, and scans otherwise
  * `member?` scans the smaller of a public list's members and the user's list memberships
* Limit the pages a scan or a count of posts reads with `max_pages:` (default nil, no limit)
  * Taken by `X::List#member?`, `X::User#follows?`, `X::Post.count`, `count_all`, `count_by_period`, `count_all_by_period`, and their client methods
  * Past the limit, with another page named, it raises `X::PageLimitReached`, an `X::Resources::Error`
  * A value that is neither an Integer of at least 1 nor nil raises `ArgumentError` before a request
* Raise `X::InvalidAttribute`, an `X::Resources::Error`, for a response value that cannot be read as the API documents it
  * Such as a timestamp that is not ISO 8601, a count that is not a whole number, or a flag that is not a boolean
  * Its cause is the `ArgumentError` that refused the value
* Validate the identifier of a resource when it is built, so `X::User.new({"id" => "abc"})` raises `ArgumentError`
  * A space or place ID is word characters alone; a `dm_conversation_id` that is not digits, or two numbers joined by a hyphen, raises `X::InvalidAttribute`
* Validate a username before building a path from it, so `find_user("../tweets/20")` raises `ArgumentError` without a request

### Changed
* Require Ruby 3.4 or later
* Hold `VERSION` in a String rather than a `Gem::Version`; use `gem_version` to compare versions
* Send requests to `api.x.com` rather than `api.twitter.com` by default
* Name the gem in the `User-Agent` header of every request, token requests included, as `x-ruby/1.0.0 ruby/3.4.0 (arm64-darwin24)`, where it named `X-Client`
* Move the HTTP client into `x-core` and the uploaders into `x-uploads`
* Rename `X::MediaUploader` to `X::Uploads::MediaUpload`, `X::AccountUploader` to `X::Uploads::Account`, and `X::MediaUploadValidator` to `X::Uploads::Validator`
* Rename `X::OAuthAuthenticator` to `X::OAuth1Authenticator`
* Rename `X::ConnectionException`, the error for 409 Conflict, to `X::Conflict`
* Rename `X::HTTPError#response` to `http_response`, and make that of `X::RateLimit` private
* Move `stream` from `X::Client` to `X::StreamingClient`
* Refresh OAuth 2.0 tokens with `X::OAuth2Authenticator#refresh!`, in place of `refresh_token!`
  * It returns the frozen `X::OAuth2Tokens` of the refresh rather than the Hash of the token response
  * It raises `X::UnsupportedOperation` for an authenticator that holds no refresh token
* Keep frozen copies of the credentials, tokens, header values, base URL, and proxy URL a client, an authenticator, an `X::OAuth2Authorization`, or `X::OAuth2Tokens` is given, so neither the caller nor what a reader returns can change what is sent, or where
* Keep secret credentials private on a client and its authenticators
  * `api_key_secret`, `access_token`, `access_token_secret`, `bearer_token`, `client_secret`, and `refresh_token` no longer read off a client
  * Nor do the secrets and tokens of the authenticators; `api_key`, `client_id`, and `expires_at` remain public
  * An authenticator's `headers` still returns the `Authorization` header it sends, which holds a bearer or OAuth 2.0 token
  * Store refreshed tokens from the `X::OAuth2Tokens` that `save_tokens` is passed
* Raise `TypeError` from `Marshal.dump`, `YAML.dump`, `as_json`, and `to_json` of a client, streaming client, authenticator, or `X::OAuth2Authorization`
* Keep the proxy of a client, streaming client, and connection private: `proxy_url` and the `proxy_*` readers are gone
  * `inspect` leaves the proxy out
* Send credentials only to the origin of the `base_url`
  * An endpoint or stream naming another scheme, host, or port gets no `Authorization`, `Cookie`, or `Proxy-Authorization` header
  * Another API version on the same origin, such as `https://api.x.com/1.1/account/settings.json`, still gets them
* Send a header named by a Symbol with its underscores as hyphens, wherever headers are taken
  * `headers: {content_type: "text/plain"}` sends `content-type`, replacing the default `Content-Type`
  * It is dropped on a cross-origin redirect like the header it names
* Raise `ArgumentError` from `X::Client.new` for a `base_url` that is not an absolute http or https URL
  * Or that holds a user, password, query, or fragment
* Raise `ArgumentError` from `X::Client.new` for credentials that do not form a complete set
  * Or for a credential that belongs to no complete set, such as a `client_id` beside a `bearer_token`
  * Or for OAuth 2.0 credentials beside a complete set of OAuth 1.0a credentials
  * Or for an empty String credential, or one that is neither a String nor nil
  * Or for an `expires_at` beside credentials it does not belong to
* Raise `ArgumentError` from the authenticators for a required credential that is nil or empty, or an `expires_at` that is not a `Time`
* Raise `ArgumentError` from `X::Client.new`, `with`, and `streaming` for settings out of range, naming the setting
  * `max_redirects`, `max_rate_limit_retries`, and `max_retries` must be Integers of at least 0
  * `max_rate_limit_wait` must be a number of at least 0, not NaN; `max_reconnects` an Integer of at least 0 or `Float::INFINITY`
  * `open_timeout`, `read_timeout`, and `write_timeout` must be finite numbers of at least 0, or nil; `keep_alive_timeout` a finite number
  * A stream's `read_timeout` must be at least 25 seconds, or nil
  * `default_array_class` must be a Class, and `default_object_class` a Class or respond to `from_response`
  * `debug_output` must be nil or take a String with `<<`, as an IO, a StringIO, or a Logger does; a String, such as `"debug.log"`, and an Integer are refused
* Raise `ArgumentError` from `get`, `post`, `put`, `delete`, `get_stream`, and `stream` for an endpoint that is not a valid URL
  * Such as one that holds a space or bad `%` escape, or does not resolve to an http or https URL with a host
  * An endpoint that is not a String, such as a Symbol or a URI, raises `ArgumentError` naming its class
* Raise `ArgumentError` from `post` and `put` for an unknown keyword, as `client.post("tweets", text: "Hello")`
* Resolve an endpoint that begins with a slash against the base URL, so `client.get("/users/me")` requests `/2/users/me`
* Open a connection with a 10-second timeout rather than 60; `read_timeout` and `write_timeout` stay 60
* Send each request once, turning off the automatic retry of `Net::HTTP`; `max_retries` decides what is sent again
* Send an idempotent request again on a new connection when a kept-alive connection had gone stale
  * Only before the status and headers of its response are read; a response cut off after that is never sent again
* Raise `X::NetworkError` for a body cut off before its end, or shorter than its `Content-Length`, rather than read what arrived
* Wrap every network failure in `X::NetworkError`, so a stream reconnects after it
  * Including `IOError`, `SystemCallError`, Net::HTTP's open, read, and write timeouts, `Net::ProtocolError`, `Zlib::Error`, `Net::HTTPBadResponse`, `OpenSSL::SSL::SSLError`, and `SocketError`, but not a `Timeout::Error` that `Timeout.timeout` raises around a request, which is raised as it is, but one raised with its class, as by `Timeout.timeout(5, Timeout::Error)`, that lands in `save_tokens` is an `X::TokenReportFailed`, holding the tokens
* Stop following redirects after exactly `max_redirects` hops instead of one more, so 0 follows none
* Request the token endpoints at the origin of the base URL, under the path it serves the API at, rather than at `api.x.com`
  * The path is the base URL's minus a trailing API version segment
  * With `base_url: "https://gateway.example/x/2/"`, an app-only token comes from `/x/oauth2/token` and a refresh goes to `/x/2/oauth2/token`
  * `X::OAuth2Authorization` exchanges its code at the base URL of the client it builds
* Raise `X::AuthorizationError`, an `X::ClientError`, when X refuses a token refresh, code exchange, or app-only token
  * It holds the OAuth 2.0 `error_code`, such as `invalid_request`, and the `status`, `headers`, and `body` of the response
  * A token endpoint that fails to answer raises the `X::HTTPError` of its status, such as `X::ServerError`, instead
  * A refresh refused after a 401 raises it with the `X::Unauthorized` as its cause
* Raise `X::AuthorizationDenied`, an `X::Error` with the `error_code` the redirect reported, for a redirect back from X that refuses
* Raise `X::InvalidResponse`, an `X::HTTPError`, for a successful response whose body is not JSON, where it returned nil
* Tag the bodies of responses, errors, and stream lines as UTF-8, so comparing them with non-ASCII text works
  * A body that is not valid UTF-8 keeps its bytes; `valid_encoding?` tells it apart
* Read only rate limits a response reports in full, in base 10
  * `X::TooManyRequests#retry_after` no longer raises `KeyError` or `ArgumentError` for a missing or malformed header
* Return nil from `X::TooManyRequests#reset_at`, `#reset_in`, and `#retry_after` when the response does not say when the limit resets
* Read `Retry-After` with `X::HTTPError#retry_after`, in seconds or as an HTTP date, or nil
  * `X::TooManyRequests#retry_after` reads it, falling back on `#reset_in`; retries and reconnects wait for it
* Report every rate limit a response names from `X::TooManyRequests#rate_limits`, not just the exhausted ones
  * `#rate_limit` reads the 15-minute limit; the exhausted limit that resets last is now `#limiting_rate_limit`
* Make `X::RateLimit.new` and `.reported?` private
* Make public, documented constructors for the errors of `x-core` and `X::Response`, so code that rescues them can be tested
  * `X::HTTPError.new(status:, headers:, body:, http_method: nil, uri: nil)`, or `http_response:` in their place
  * `raise X::NotFound` and `raise X::TooManyRequests, "slow down"` work as for any exception
  * `X::Response.new(http_method:, uri:, status:, headers:, body:)`, or `http_response:` in their place
  * A status outside 100 to 599, or headers that are not a Hash, raise `ArgumentError`
* Name the internal classes of `x-core` under `X::Core` and those of `x-streams` under `X::Streams`, as private constants
* Make `X::Connection` the internal `X::Core::Connection`
  * The authenticators take no `connection:`
  * `X::OAuth2Authorization` takes `base_url`, `proxy_url`, `open_timeout`, `read_timeout`, `write_timeout`, `debug_output`, and `headers` instead
* Make the constants that hold messages, patterns, or internal defaults of `x-core` private
  * `X::HTTPError::JSON_CONTENT_TYPE_REGEXP` and `X::OAuth2Authenticator::EXPIRATION_BUFFER`
* Make `X::Uploads::Validator` and the MIME type and size constants of `X::Uploads::MediaUpload` private
  * `MIME_TYPES`, `MIME_TYPE_MAP`, the `*_MIME_TYPE` constants, `BYTES_PER_MB`, `MAX_SIMPLE_UPLOAD_BYTES`, and the endpoints of `X::Uploads::Account`
  * The media category constants, such as `TWEET_IMAGE`, remain public
* Make `infer_media_type` of `X::Uploads::MediaUpload` internal; pass `media_type:` to override the type an upload infers
* Ship the signatures of the public interface alone in each gem
* Document every error class of `x-core` and draw the whole hierarchy on `X::Error`
* Sign OAuth 1.0a requests, and build OAuth 2.0 token refreshes, with the [simple_oauth](https://github.com/laserlemon/simple_oauth) gem
* Take media as a path (`String` or `Pathname`) or an IO in `upload_media`, `upload`, `chunked_upload`, `update_profile_image`, and `update_profile_banner`
  * A `File` or `Tempfile` is read a chunk at a time; another IO, such as a `StringIO`, is read whole
  * A String holding a NUL byte or a line break raises `ArgumentError`; pass a path or a `StringIO`
  * An IO that cannot be read, or that the system refuses to read, such as a socket that is not connected, or a `File` closed while it is read, raises `X::InvalidMedia`
* Infer the type of media from the bytes it begins with before the name of its file
  * GIF, PNG, JPEG, BMP, TIFF, WebP, MP4, QuickTime, WebM, MPEG-TS, and WebVTT are recognized
  * Media of a type nothing names, such as HEIC or SubRip in a `StringIO`, raises `X::InvalidMediaType` without `media_category:`
  * A file named as a type every file of which begins with a signature, but without it, such as TypeScript named `.ts`, raises `X::InvalidMediaType`; otherwise the bytes win over the name
  * A type the media category does not take, such as MP4 with `"tweet_gif"`, raises `X::InvalidMediaType`
* Raise `X::MissingMediaData` instead of `KeyError` or nil when an upload, status check, or metadata response holds no media
  * Its `problems` hold the problems the response reported, the first named in its message
* Raise `X::InvalidMedia` for a file that does not exist, and `X::MediaProcessingFailed` for media that fails to process, instead of `RuntimeError`
  * `X::MediaProcessingFailed#media` holds what X reported as an `X::UploadedMedia`
* Raise `ArgumentError` from `await_processing`, `add_alt_text`, and `add_subtitles` for media without an `"id"`
* Raise `ArgumentError` from `add_subtitles` for a language code that is not two letters
* Upload in chunks of 4 MB, `X::Uploads::MediaUpload::DEFAULT_CHUNK_SIZE`, rather than 1 MB, so a video takes a quarter of the requests
  * A file larger than the 16 GB the API takes raises `X::InvalidMedia` before the upload
  * `chunk_size:` replaces `chunk_size_mb:`, takes bytes, and defaults to nil, which uploads in chunks of 4 MB
* Upload an animated GIF larger than 5 MB in chunks, which the API takes up to 15 MB of
* Validate the `alt_text:` of `upload` before uploading, so media is not lost to a refused alt text
* Post profile images and banners to the API v1.1 through the client's base URL, credentials, and connections
* Keep the state and helpers of `X::Client` in an internal object, so mixed-in methods never collide with them

### Removed
* Remove `X::MediaUploader.upload_binary`; pass a `StringIO` to `X::Uploads::MediaUpload.upload`
* Remove `upload_profile_image_binary` and `upload_profile_banner_binary`; pass an IO to `update_profile_image` and `update_profile_banner`
* Remove `require "x/media_uploader"` and `require "x/account_uploader"`; require `x`, `x/uploads/media_upload`, or `x/uploads/account`
* Remove the `boundary:` of the upload methods, which each upload now generates for itself
* Remove `X::AccountUploader::MIME_TYPE_MAP`
* Remove `X::Uploads::MediaUpload::PROCESSING_INFO_STATES`; use `X::UploadedMedia#processing?`
* Remove `X::Uploads::MediaUpload::MAX_RETRIES`; a chunk is retried up to the client's `max_retries`
* Remove `X::HTTPError#code`; use `#status`, an Integer, or `error.http_response.code`
* Remove `X::HTTPError#error_message` and `#message_from_json_response`, and make `#json?` private
* Remove `X::RateLimit#retry_after`; read `#reset_in`
* Remove the setters of `X::Client`; derive a client that differs with `X::Client#with`
  * `api_key=`, `api_key_secret=`, `access_token=`, `access_token_secret=`, `bearer_token=`, `client_id=`, `client_secret=`, `refresh_token=`
  * `base_url=`, `default_array_class=`, `default_object_class=`, `open_timeout=`, `read_timeout=`, `write_timeout=`, `proxy_url=`, `debug_output=`, `max_redirects=`
* Remove the setters of `X::Connection`, `X::RateLimit`, `X::BearerTokenAuthenticator`, `X::OAuth1Authenticator`, and `X::OAuth2Authenticator`
* Remove `X::Connection::DEFAULT_HOST` and `DEFAULT_PORT`
* Remove `X::OAuth1Authenticator#access_token`; `user_id` reads the user the token acts for
* Remove `X::OAuthAuthenticator::OAUTH_SIGNATURE_ALGORITHM`, `OAUTH_VERSION`, and `OAUTH_SIGNATURE_METHOD`
* Remove `X::OAuth2Authenticator::REFRESH_GRANT_TYPE`, `TOKEN_HOST`, and `TOKEN_PATH`; tokens are requested at the origin of the `base_url`
* Remove the `base64` dependency

### Fixed
* Keep the method and body of a `PUT` or `DELETE` that a 301 or 302 redirects, as RFC 9110 has it
  * A `POST` redirected by a 301 or 302, and any request redirected by a 303, is still followed with a `GET`
* Resolve a relative redirect against the URL of the request, rather than the base URL
* Raise `X::HTTPError` for a redirect that cannot be followed, instead of `KeyError`, `URI::InvalidURIError`, or `ArgumentError`
  * A 300, 304, or 305, or one whose `Location` is missing, invalid, or not HTTP or HTTPS
* Send the credentials on every redirected request, not only the first
* Drop the credentials and any `Authorization`, `Cookie`, or `Proxy-Authorization` header on a redirect to another origin
* Preserve the headers passed to `get`, `post`, `put`, and `delete` across redirects
* Send no `Authorization` header from a client without credentials, rather than an empty one
* Send a `Content-Type` header only with a request that carries a body
* Build the message of an `X::HTTPError` from a body that is not JSON, or whose errors have no `message`
  * Instead of raising `JSON::ParserError`, `KeyError`, or `TypeError` in place of the error
* Raise `X::ClientError` or `X::ServerError` for an unnamed 4xx or 5xx status, such as 411 or 501, instead of `X::HTTPError`
* Raise the errors of `on_response`, a request's block, or the object class as they were raised
  * The request is not retried, rate-limited, or refreshed, and a stream does not reconnect for them
* Send a query parameter without a value, as the `flag` of `get("users?flag")`, without `=`
* Connect to a host or proxy named by an IPv6 literal, such as `http://[::1]:8080/`; `x-core` depends on net-http 0.9.1 or later
* End a `base_url` without a trailing slash with one, so `https://api.x.com/2` requests `/2/users/me`
* Take the proxy from `https_proxy` for HTTPS requests and `http_proxy` for HTTP, and honor `no_proxy`
  * A proxy there that cannot be parsed, or that is not an http or https URL with a host, as `proxy.example.com:8080` is not, raises `ArgumentError` from each request that opens a connection, and from `get_stream`, naming the variables read for its scheme and leaving out the value
* Connect to an `https://` proxy over TLS
* Decode a percent-encoded proxy user and password
* Leave the proxy user and password out of the message of an invalid proxy URL, and raise `ArgumentError` for one
* Sign a form-encoded request body with OAuth 1.0a
* Sign every value of a repeated query parameter
* Sign the normalized URL, so a request to a host with no path signs `/`
* Form-encode the client credentials before Basic authentication on token refresh, as RFC 6749 Section 2.3.1 requires
* Refresh an OAuth 2.0 token through the connection of the client that sends the request, with its proxy and timeouts
* Declare `X::BadGateway` and `X::GatewayTimeout` as `X::ServerError`s in the signatures
* Declare the standard libraries each gem's signatures refer to in its `sig/manifest.yaml`
* Link each gem's `changelog_uri` to the `main` branch rather than `master`
* Parse uploader responses into Hashes and Arrays whatever the client's `default_object_class` and `default_array_class`
* Return nil from `update_profile_image` and `update_profile_banner`; look the user up to read what it holds
* Raise `X::InvalidMedia` from `update_profile_image` and `update_profile_banner` for an empty or oversized file
  * A profile image larger than 700 KB or a banner larger than 5 MB
  * `X::InvalidMediaType` for one that is not a GIF, JPEG, or PNG; `ArgumentError` for a non-integer banner offset or size
* Accept the `amplify_video` media category, and subtitle such a video with `add_subtitles`
* Upload every media type the API documents: WebM, QuickTime, and MPEG-TS videos, WebVTT subtitles, and BMP, TIFF, and progressive JPEG images
* Upload an `.m4v` file as an MP4 video, in chunks
* Raise `X::InvalidMediaType` before a request for `.glb` and `.usdz` files, and for `.avi` and `.mkv` files unless they begin with the signature of a type the API documents, as WebM does
* Upload subtitles in chunks as `text/srt`, the type the API names
* Send the media category in lowercase, as the API documents it
* Raise `X::InvalidMedia` from the uploaders, before any request, for media that cannot be uploaded
  * An empty file, a directory, a file that cannot be read, or an IO open for writing alone
  * A `Pathname` of a missing file, as for a `String`, instead of `TypeError`
  * An image over 5 MB, a GIF over 15 MB, or subtitles over 1 MB
* Raise `X::MissingMediaData` before a chunk is uploaded when the initialize response holds no media, instead of `NoMethodError`
* Give up waiting for media to process after the `processing_timeout:` (default 600 seconds), raising `X::MediaProcessingTimeout`
  * Taken by `upload`, `await_processing`, `await_processing!`, `upload_media`, and `await_media_processing(!)`
  * `processing_timeout:` takes a finite number of seconds of at least 0, or nil for no limit
  * Anything else, `Float::INFINITY` included, raises `ArgumentError` before the first request
  * Checks wait at least a second apart when X asks for no wait
  * Only `succeeded` and `failed` end the wait; any other state, even one X does not document, is still `processing?`
* Retry a failed chunk, and the finalize request, with the client's `max_retries`, backing off rather than retrying at once
* Upload the chunks of a video four at a time, or the `concurrency:` of `chunked_upload` (at most 16), instead of a thread per chunk
  * A chunk that fails stops the chunks not yet begun
* Stop the chunks of a chunked upload when the waiting thread is interrupted, such as by a timeout
  * Including a `ThreadError` or interrupt while the chunk threads are being started
  * A chunk storing the tokens of a refresh it made with `save_tokens` finishes storing them first
  * A chunk reading from the file finishes reading first, so the file is closed rather than left open
* Raise `ArgumentError` from `chunked_upload`, before any request, for an invalid `chunk_size` or `concurrency`
  * `chunk_size` must be a positive Integer of at most 5,242,880 bytes, within the 10,000 segments the API numbers
  * `concurrency` must be an Integer from 1 to `MAX_CONCURRENCY` (16)
* Read the size of chunked upload media once, so a growing file uploads the declared `total_bytes`
* Give a class that includes `X::Uploads::MediaUpload` or `X::Uploads::Account` their public methods and constants alone, so its own methods do not break uploads

## [0.19.0] - 2026-03-01
* Add streaming support for filtered stream and volume stream endpoints

## [0.18.0] - 2026-01-06
* Add OAuth 2.0 authentication with token refresh support (d4c03cb)
* Add AccountUploader for profile image and banner uploads (7833dd2)
* Raise InvalidMediaType error for unsupported file extensions (2b6eacc)
* Prioritize errors array over title/detail in error messages (75279b9)

## [0.17.0] - 2025-12-02
* Add MediaUploader.upload_binary method (9f2f108)
* Don't forward filename during media upload (492214d)

## [0.16.0] - 2025-06-24
* Remove media_type parameter from non-chunked upload and append methods (f1f38b5)
* Fix media upload (dcb418a)
* Add await_processing! method to handle media upload failures (6cfc973)
* Move media_category in body for media upload (b790636)

## [0.15.4] - 2025-05-02
* Use dedicated endpoints for chunked media upload (d54d0d0)

## [0.15.3] - 2025-04-24
* Add missing base64 dependency (3ca8512)
* Set binary read for media files to be uploaded (fd066e6)

## [0.15.2] - 2025-03-28
* Use media_id instead of media_key to upload media (f1dd577)

## [0.15.1] - 2025-03-24
* Fix bug in MediaUploader#await_processing (136dff8)
* Refactor RedirectHandler#build_request (fd379c3)
* Escape space in query string as %20, not + (2d2df75)
* Don't escape commas in query parameters (e7d9056)

## [0.15.0] - 2025-02-06
* Change media upload to use the API v2 endpoints (eca2b88)

## [0.14.1] - 2023-12-20
* Fix infinite loop when an upload fails (5dfc604)

## [0.14.0] - 2023-12-08
* Allow passing custom objects per-request (768889f)

## [0.13.0] - 2023-12-04
* Introduce X::RateLimit, which is returned with X::TooManyRequests errors (196caec)

## [0.12.1] - 2023-11-28
* Ensure split chunks are written as binary (c6e257f)
* Require tmpdir in X::MediaUploader (9e7c7f1)

## [0.12.0] - 2023-11-02
* Ensure Authenticator is passed to RedirectHandler (fc8557b)
* Add AUTHENTICATION_HEADER to X::Authenticator base class (85a2818)
* Introduce X::HTTPError (90ae132)
* Add `code` attribute to error classes (b003639)

## [0.11.0] - 2023-10-24
* Add base Authenticator class (8c66ce2)
* Consistently use keyword arguments (3beb271)
* Use patern matching to build request (4d001c7)
* Rename ResponseHandler to ResponseParser (498e890)
* Rename methods to be more consistent (5b8c655)
* Rename MediaUpload to MediaUploader (84f0c15)
* Add mutant and kill mutants (b124968)
* Fix authentication bug with request URLs that contain spaces (8de3174)
* Refactor errors (853d39c)
* Make Connection class threadsafe (d95d285)

## [0.10.0] - 2023-10-08
* Add media upload helper methods (6c6a267)
* Add PayloadTooLargeError class (cd61850)

## [0.9.1] - 2023-10-06
* Allow successful empty responses (06bf7db)
* Update default User-Agent string (296b36a)
* Move query parameter escaping into RequestBuilder (56d6bd2)

## [0.9.0] - 2023-09-26
* Add support for HTTP proxies (3740f4f)

## [0.8.1] - 2023-09-20
* Fix bug where setting Connection#base_uri= doesn't update the HTTP client (d5a89db)

## [0.8.0] - 2023-09-14
* Add (back) bearer token authentication (62e141d)
* Follow redirects (90a8c55)
* Parse error responses with Content-Type: application/problem+json (0b697d9)

## [0.7.1] - 2023-09-02
* Fix bug in X::Authenticator#split_uri (ebc9d5f)

## [0.7.0] - 2023-09-02
* Remove OAuth gem (7c29bb1)

## [0.6.0] - 2023-08-30
* Add configurable debug output stream for logging (fd2d4b0)
* Remove bearer token authentication (efff940)
* Define RBS type signatures (d7f63ba)

## [0.5.1] - 2023-08-16
* Fix bearer token authentication (1a1ca93)

## [0.5.0] - 2023-08-10
* Add configurable write timeout (2a31f84)
* Use built-in Gem::Version class (066e0b6)

## [0.4.0] - 2023-08-06
* Refactor Client into Authenticator, RequestBuilder, Connection, ResponseHandler (6bee1e9)
* Add configurable open timeout (1000f9d)
* Allow configuration of content type (f33a732)

## [0.3.0] - 2023-08-04
* Add accessors to X::Client (e61fa73)
* Add configurable read timeout (41502b9)
* Handle network-related errors (9ed1fb4)
* Include response body in errors (a203e6a)

## [0.2.0] - 2023-08-02
* Allow configuration of base URL (4bc0531)
* Improve error handling (14dc0cd)

## [0.1.0] - 2023-08-02
* Initial release

[1.0.0]: https://github.com/sferik/x-ruby/compare/v0.19.0...v1.0.0
[0.19.0]: https://github.com/sferik/x-ruby/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/sferik/x-ruby/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/sferik/x-ruby/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/sferik/x-ruby/compare/v0.15.4...v0.16.0
[0.15.4]: https://github.com/sferik/x-ruby/compare/v0.15.3...v0.15.4
[0.15.3]: https://github.com/sferik/x-ruby/compare/v0.15.2...v0.15.3
[0.15.2]: https://github.com/sferik/x-ruby/compare/v0.15.1...v0.15.2
[0.15.1]: https://github.com/sferik/x-ruby/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/sferik/x-ruby/compare/v0.14.1...v0.15.0
[0.14.1]: https://github.com/sferik/x-ruby/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/sferik/x-ruby/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/sferik/x-ruby/compare/v0.12.1...v0.13.0
[0.12.1]: https://github.com/sferik/x-ruby/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/sferik/x-ruby/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/sferik/x-ruby/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/sferik/x-ruby/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/sferik/x-ruby/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/sferik/x-ruby/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/sferik/x-ruby/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/sferik/x-ruby/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/sferik/x-ruby/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/sferik/x-ruby/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/sferik/x-ruby/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/sferik/x-ruby/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/sferik/x-ruby/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/sferik/x-ruby/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/sferik/x-ruby/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/sferik/x-ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sferik/x-ruby/releases/tag/v0.1.0
