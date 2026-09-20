# Upgrading

## From 0.19 to 1.0

Version 1.0 splits the gem into `x-core`, `x-uploader`, `x-streaming`, and `x-objects`. The `x` gem depends on all four, and `require "x"` loads them.

Version 1.0 renames or removes what 0.19 had under old names, without deprecating them first. This guide covers what code written for 0.19 needs to change. See [CHANGELOG.md](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) for everything that was added.

### Ruby

Version 1.0 requires Ruby 3.4 or later.

### Credentials

`X::Client.new` checks its credentials, where 0.19 sent requests without the ones it could not use:

* Credentials that do not form a complete set raise `ArgumentError`. Pass one of these sets:
  * OAuth 1.0a: `api_key`, `api_key_secret`, `access_token`, and `access_token_secret`.
  * OAuth 2.0: `client_id` and `access_token`, plus the `refresh_token` that refreshes it and, for a confidential client, `client_secret`.
  * App-only: `bearer_token`.
  * App-only: `api_key` and `api_key_secret` alone.
* An OAuth 2.0 token issued without the `offline.access` scope has no refresh token. Pass `client_id` and `access_token` alone.
  * Such a client acts for the user and refreshes nothing. 0.19 sent its requests without credentials.
* A `bearer_token` is the app's. Endpoints that take app-only authentication, such as streams, are sent it.
* A credential outside a complete set raises `ArgumentError`, rather than being ignored. Leave it out.
  * For example, a `client_id` or an `api_key` beside a `bearer_token`.
* A client may hold several complete sets, such as an app's bearer token beside its API key and secret. It authenticates with the first, in the order above.
* OAuth 2.0 credentials beside a complete OAuth 1.0a set raise `ArgumentError`, since they would share its access token.
* `expires_at` is allowed only beside the OAuth 2.0 `client_id` and `access_token` the client authenticates with. Anywhere else it raises `ArgumentError`.
* A credential that is an empty String raises `ArgumentError`. 0.19 sent it for the API to refuse.
  * Watch for an unset environment variable read as `ENV.fetch("X_BEARER_TOKEN", "")`.

A client, its authenticators, and `X::RateLimit` are read-only. Derive a changed client with `with`, which takes anything `X::Client.new` takes and checks it the same way:

```ruby
# 0.19
client.authenticator.access_token = "new_token"

# 1.0
rotated = client.with(access_token: "new_token", access_token_secret: "new_secret")
```

* A client keeps its credentials and settings for life, so a request never signs with a mix of old and new credentials.
* These setters are gone. Pass the option to `with` instead, as `client.with(read_timeout: 30)`:
  * On `X::Client`: `base_url=`, `default_array_class=`, `default_object_class=`, `open_timeout=`, `read_timeout=`, `write_timeout=`, `debug_output=`, `proxy_url=`, `max_redirects=`, and the setter of each credential.
  * On the authenticators: the setter of each credential, and `connection=`.
  * On `X::RateLimit`: `type=` and `response=`.
* The credentials of a copy must form a complete set. Clearing one so that the set is incomplete raises `ArgumentError`.
* A client and its copies with the same OAuth 2.0 credentials share one authenticator, so a refresh by any of them reaches all.
* A copy given other OAuth 2.0 credentials, such as another user's access token, drops the client's `refresh_token`, `expires_at`, `scopes`, `save_tokens`, and `load_tokens`.
  * Before: a setter changed one credential and kept the rest.
  * After: pass the refresh token, `save_tokens:`, and `load_tokens:` beside the access token they belong to.
* Clients built separately share an authenticator when each is given it as `authenticator:`, in place of credentials.

A client refreshes an OAuth 2.0 access token itself, where 0.19 never did:

* It refreshes when the `expires_at` it was given passes, or when X rejects the token.
* X issues a new refresh token with each refresh and no longer accepts the old one.
* Store the new tokens from `save_tokens:`, as below, or the stored refresh token stops working.
* Processes that share a user's tokens also pass `load_tokens:`, a callable that reads the store, so none refreshes with a refresh token another already spent.

A client and its authenticator no longer reveal secret credentials:

* These are private on `X::Client`, where 0.19 read them: `api_key_secret`, `access_token`, `access_token_secret`, `bearer_token`, `client_secret`, and `refresh_token`.
* These are private on the authenticators, so `client.authenticator` reads none of them by name:
  * `api_key_secret`, `access_token_secret`, and `client_secret`.
  * `bearer_token` of `X::BearerTokenAuthenticator` and `X::AppOnlyAuthenticator`.
  * `access_token` and `refresh_token` of `X::OAuth2Authenticator`, which 0.19 read.
  * `access_token` of `X::OAuth1Authenticator`, which 0.19 read off `X::OAuthAuthenticator`.
* `inspect` reveals no secret.
* An authenticator's `headers` still returns the headers it signs a request with, since a custom authenticator overrides it.
  * The `Authorization` header of a bearer token, an app-only token, and an OAuth 2.0 access token holds the token itself, so guard an authenticator as you guard its client.
* Still public on a client: `api_key`, `client_id`, and the new `expires_at`. On an OAuth 2.0 authenticator: `client_id` and `expires_at`.
* Read the user an OAuth 1.0a access token names with `X::Authenticator#user_id`, rather than parsing the token.
* Read refreshed tokens from the frozen `X::OAuth2Tokens` passed to `save_tokens`, and carry credentials to another client with `with`:

```ruby
# 0.19
store(client.access_token, client.refresh_token)

# 1.0
X::Client.new(**credentials, save_tokens: ->(tokens) { store(tokens.access_token, tokens.refresh_token, tokens.expires_at) })
```

Clients and credentials refuse to be serialized, where 0.19 wrote them, credentials and all, in the clear:

* A client, a streaming client, an authenticator, and an `X::OAuth2Authorization` raise `TypeError` from `Marshal.dump`, `YAML.dump`, `as_json`, and `to_json`.
  * This catches a client held in a cached Hash, a job argument a queue writes as YAML, and `render json:`.
* Keep credentials in a secret store, and build the client again from them.
* `X::OAuth2Tokens` still marshal, tokens and all, since they are meant to be stored.
  * They write themselves as JSON with `to_json`, and `X::OAuth2Tokens.from_json` reads it back.

An OAuth 2.0 authenticator's `refresh_token!` is now `refresh!`:

* Before: it returned the Hash of the token response.
* After: it returns the frozen `X::OAuth2Tokens` of that refresh, the object `save_tokens` is passed.
* Read the new tokens from what it returns. The authenticator's tokens are private, and another thread's refresh may replace them.
* A refresh X refuses raises `X::AuthorizationError`, an `X::ClientError`, where 0.19 raised an `X::Error` whose message was the `error_description`.
  * Its `error_code` is the OAuth 2.0 error, such as `invalid_grant`. Read it rather than the message.
  * A token endpoint that fails to answer raises the `X::HTTPError` of its status, such as `X::ServerError`.
  * `rescue X::Error` catches both, as it did.

```ruby
# 0.19
store(client.authenticator.refresh_token!["refresh_token"])

# 1.0
store(client.authenticator.refresh!.refresh_token)
```

Token requests go to the origin of the base URL, where 0.19 sent them to `api.x.com` whatever the base URL:

* This is the app-only bearer token, an OAuth 2.0 refresh, and the code exchange of `X::OAuth2Authorization`.
* The path is the base URL's minus a trailing API version segment.
  * With `base_url: "https://gateway.example/x/2/"`, an app-only token comes from `/x/oauth2/token` and a refresh goes to `/x/2/oauth2/token`.
* A client whose base URL names a gateway or proxy sends its tokens there, so it must forward the token endpoints to X too.

A custom authenticator overrides `headers`, where 0.19 overrode `header`:

* It returns the headers that authenticate a request, as `header` did.
* Before: it was passed the `Net::HTTPRequest`, whose `method` is a String such as `"POST"`.
* After: the request it is passed answers only `http_method` (a Symbol such as `:post`), `uri`, `body`, and `[]` for a header.

```ruby
# 0.19
def header(request) = {"Authorization" => sign(request.method, request.uri)}

# 1.0
def headers(request) = {"Authorization" => sign(request.http_method.to_s.upcase, request.uri)}
```

### Requests

An endpoint that begins with a slash is relative to the base URL, like one without:

* Before: `/1.1/...` resolved against the host, dropping the `/2/` path of the base URL.
* After: pass a whole URL, or derive a client with another `base_url`, to reach another API version.

```ruby
# 0.19
client.get("/1.1/account/settings.json")

# 1.0
client.with(base_url: "https://api.x.com/1.1/").get("account/settings.json")
client.get("https://api.x.com/1.1/account/settings.json")
```

Credentials are sent only to the origin of the `base_url`:

* The default `base_url` is `https://api.x.com/2/`, where 0.19 defaulted to `https://api.twitter.com/2/`.
  * Pass whole URLs on `api.x.com`, or a `base_url` on `api.twitter.com`, so whole URLs keep the client's credentials.
* An endpoint or stream is signed only when it has the scheme, host, and port of the `base_url`. 0.19 signed a request to any host.
* A request to another origin is sent without any `Authorization`, `Cookie`, or `Proxy-Authorization` header, the client's or the request's.
* A redirect off the origin drops them too. 0.19 signed the first redirect for whatever host it named.
* To reach another host with its own credentials, build a client for it with its own `base_url`.
* Token endpoints (app-only and OAuth 2.0) are requested at the origin of the `base_url`. 0.19 always used `api.x.com`.
  * So a client pointed at a test server or recording proxy fetches and refreshes its tokens there.

Invalid endpoints raise `ArgumentError` before any request:

* An endpoint that is not a valid URL (such as one holding a space), or not an http or https URL with a host, raises `ArgumentError` naming it.
  * Before: `URI::InvalidURIError`, or a `Net::HTTP` `ArgumentError` that named nothing.
  * After: rescue `ArgumentError` where code rescued `URI::InvalidURIError`.
* An endpoint that is not a String, such as a Symbol or a `URI`, raises `ArgumentError`. Pass `uri.to_s`.

Requests are retried by the client, not by `Net::HTTP`:

* Before: `Net::HTTP` resent a GET, PUT, or DELETE after a timeout or dropped connection, reusing the OAuth 1.0a nonce and signature. A 5xx raised at once.
* After: the client resends a GET, PUT, or DELETE after `X::ServerError`, `X::RequestTimeout`, or an `X::NetworkError` for a request that never reached the API.
  * It does not resend after a read timeout, since the API bills a read it answered.
  * It retries `max_retries` times, twice by default, signing each attempt afresh.
  * It waits as long as a `Retry-After` header asks, up to a minute. A response asking for longer raises at once.
* Pass `max_retries: 0` to raise at once, as code with its own retry loop may want. See the retries in [README.md](https://github.com/sferik/x-ruby/blob/main/README.md).

### Renamed classes

| 0.19 | 1.0 |
| --- | --- |
| `X::OAuthAuthenticator` | `X::OAuth1Authenticator` |
| `X::ConnectionException` | `X::Conflict` |
| `X::MediaUploader` | `X::Uploader::MediaUpload` |
| `X::AccountUploader` | `X::Uploader::Account` |

Remove `require "x/media_uploader"` and `require "x/account_uploader"`. `require "x"` loads the uploaders.

`X::MediaUploadValidator` is gone, with no public replacement:

* The uploaders validate their own arguments, raising `ArgumentError` for an invalid category.
* Pass a file to `upload`. It raises `X::InvalidMedia` for a missing file, and infers the type it sends.
* The media category constants of `X::Uploader::MediaUpload`, such as `TWEET_IMAGE`, remain public.
* These are now private constants: `X::Uploader::Validator`, `X::Uploader::Chunks`, `X::Uploader::Multipart`, and `X::Uploader::Utils`.
* These constants of `X::Uploader::MediaUpload` are private: `MIME_TYPES`, `MIME_TYPE_MAP`, `BYTES_PER_MB`, and the MIME type constants, such as `GIF_MIME_TYPE`, `MP4_MIME_TYPE`, and `SUBRIP_MIME_TYPE`.
* `PROCESSING_INFO_STATES` is gone. Use `X::UploadedMedia#processing?`.

### Uploads

The uploaders take the file, content, or media as their first argument, and the client as a keyword. `upload_profile_image_binary` and `upload_profile_banner_binary` are gone: pass the content to `update_profile_image` or `update_profile_banner` as a `StringIO`.

```ruby
# 0.19
media = X::MediaUploader.upload(client:, file_path: "cat.jpg", media_category: "tweet_image")
video = X::MediaUploader.chunked_upload(client:, file_path: "cat.mp4", media_category: "tweet_video")
X::MediaUploader.await_processing!(client:, media: video)
X::AccountUploader.update_profile_image(client:, file_path: "avatar.png")
X::AccountUploader.upload_profile_image_binary(client:, content:)
X::AccountUploader.upload_profile_banner_binary(client:, content:)

# 1.0
media = X::Uploader::MediaUpload.upload("cat.jpg", client:)
video = X::Uploader::MediaUpload.upload("cat.mp4", client:) # uploads in chunks and awaits processing
X::Uploader::Account.update_profile_image("avatar.png", client:)
X::Uploader::Account.update_profile_image(StringIO.new(content), client:)
X::Uploader::Account.update_profile_banner(StringIO.new(content), client:)

# 1.0, as methods of a client, which require "x" adds
media = client.upload_media("cat.jpg")
client.update_profile_image("avatar.png")
```

* `upload` infers the media category from the media, and still takes `media_category:`.
* No upload method takes `boundary:`. Each upload generates its own multipart boundary.
* `await_processing` and `await_processing!` take the media as one argument: an upload response, a media ID, or anything that answers `media_key`, such as an `X::Media`.
* A class that includes `X::Uploader::MediaUpload` gains only its public methods.
  * Private ones it gained in 0.19, such as `init`, `append`, and `construct_upload_body`, are gone from it.
* `client.chunked_upload_media` uploads in chunks and returns without awaiting processing, as `chunked_upload` does.

Media can be a path or an IO, where 0.19 took a path alone:

* `upload` and `chunked_upload` take a `String` or `Pathname` path, or an IO open on the media.
* A path, `File`, or `Tempfile` is read a chunk at a time, so media of any size uploads without being held in memory.
* Any other IO, such as a `StringIO`, is read to its end and held in memory.
* Media that names no file is categorized by its leading bytes, so `client.upload_media(StringIO.new(png))` uploads an image.
* Media whose type neither its bytes nor its file name reveal raises `X::InvalidMediaType` unless `media_category:` names it.
  * For example, SubRip subtitles in a `StringIO`, or a PDF.

The profile image and banner of `X::Uploader::Account` are checked before any request:

* They take a path or an IO, where 0.19 took a path alone.
* They must begin with the signature of a GIF, JPEG, or PNG, whatever the file name, or raise `X::InvalidMediaType`.
  * Before: a file was taken by its extension, so a video named `.png` was sent.
* A profile image over 700 KB, or a banner over 5 MB, raises `X::InvalidMedia`.
* A banner's `width:` or `height:` that is not a positive `Integer` raises `ArgumentError`. 0.19 sent it as given.
* A banner's `offset_left:` or `offset_top:` that is not an `Integer` of at least 0, such as `"1500"`, raises `ArgumentError`.
* Content given as a `StringIO` raises `X::InvalidMedia` if empty, and `X::InvalidMediaType` if not a GIF, JPEG, or PNG.
* They are posted with the client given, and its credentials, to API v1.1 at the host of its `base_url`.
  * Before: they built their own client for `https://api.x.com/1.1/` from the OAuth 1.0a credentials.
* `update_profile_image` returns nil, as `update_profile_banner` does. 0.19 returned the API v1.1 user Hash.
  * Look the user up, as with `client.current_user!` of `x-objects`, to read the new profile image.

`upload_binary` is gone. A client has no `upload_media_binary`:

* Pass content in memory as a `StringIO` to `upload_media` or `X::Uploader::MediaUpload.upload`. They infer its category, or take `media_category:`.
* An image, or a GIF small enough, uploads in a single request, as `upload_binary` did.
* A video, subtitles, or a larger GIF uploads in chunks, which sends their media type and has no 5 MB limit. 0.19 sent them in a single request.
* They await processing of media that X processes.

```ruby
# 0.19
X::MediaUploader.upload_binary(client:, content:, media_category: "tweet_image")

# 1.0
client.upload_media(StringIO.new(content))                            # the category read from the signature
client.upload_media(StringIO.new(content), media_category: "tweet_image")
X::Uploader::MediaUpload.upload(StringIO.new(content), client:, media_category: "tweet_image")
```

`upload`, `chunked_upload`, `await_processing`, and `await_processing!` return a frozen `X::UploadedMedia`, rather than a Hash:

* It reads like the Hash did, with `[]`, `fetch`, `dig`, and `key?`, so `media["size"]` and `media.dig("processing_info", "state")` still work.
* `to_h` returns the Hash, for code that compares it with a Hash or calls `merge`.
* It also answers `id`, `media_key`, `bytesize` (what `media["size"]` holds), `expires_after_secs`, `state`, `processing?`, `failed?`, and `ready?`.
* `media.id` is an Integer. `media["id"]`, `to_h`, `as_json`, and `to_json` keep the String the API gave, as 0.19 did.
* `media_ids:` still sends each ID as a String.
* For media X processes, such as a video or an animated GIF, `upload` returns the processing status rather than the upload response. Both hold the ID.
* The other uploaders return Hashes and Arrays, whatever the client's `default_object_class` and `default_array_class`.
  * Before: `X::MediaUploader` parsed its responses with the client's classes.

The media type sent is read from the media:

* `infer_media_type` is internal, where 0.19 documented it. Pass `media_type:` to `upload` or `chunked_upload` to send another type.
* An upload sends the type the bytes name, or else the extension's.
  * Before: `video/mp4` for every video. After: for example, `video/quicktime` for `clip.mov`.
  * Before: `application/x-subrip` for SubRip subtitles. After: `text/srt`.
* Media of a type its category does not take raises `X::InvalidMediaType` before any request.
  * For example, an MP4 uploaded as `tweet_gif`, `dm_gif`, or `subtitles`, or a PNG uploaded as `tweet_video`.
  * Before: it was sent as the category's first type, such as an MP4 sent as a GIF.
  * After: pass the right category, or `media_type:` to `chunked_upload` to send it as another type.
* Content in memory raises it too, when its signature names a type its category does not take, or names none for a GIF category.
* A file named as a type whose files all begin with a signature, such as `.png`, `.gif`, or `.ts`, raises `X::InvalidMediaType` if it lacks it.
  * For example, TypeScript named `.ts`.
* Bytes win over the name, so a PNG named `.gif` uploads as an image.
* These raise `X::InvalidMediaType`, whatever `media_category:` says, unless uploaded in chunks with `media_type:` naming the type:
  * An `.avi` or `.mkv` file that does not begin with the signature of a documented type, such as MP4 or WebM.
  * Matroska media that is not WebM.
  * A `.glb` or `.usdz` file.
  * Before: any of them uploaded as MP4 when told it was a video.

Processing and failures raise errors of their own:

* `await_processing!` raises `X::MediaProcessingFailed`, rather than `RuntimeError`.
* `await_processing` raises `X::MediaProcessingTimeout` after 600 seconds, rather than waiting forever.
  * Pass `processing_timeout: nil` to wait as long as processing takes, as 0.19 did.
  * Otherwise pass a finite number of seconds. `Float::INFINITY` raises `ArgumentError`.
  * The same goes for `upload` and the client's `upload_media`, `await_media_processing`, and `await_media_processing!`.
* It waits only while X reports processing pending or in progress. 0.19 kept checking until it failed or succeeded.
  * Media in a state X does not document, or in none, is returned after that check, neither `processing?` nor `ready?`.
  * `await_processing!` and `upload` raise `X::MediaProcessingFailed` for it, naming the state.
* Media that already says its processing ended, or an image's upload response, is returned without a request. 0.19 checked it again.
* An upload response that describes no media, or has a nil or empty ID, raises `X::MissingMediaData`.
* Media given with no ID, such as nil or `{}`, raises `ArgumentError` before any request, as does `X::UploadedMedia.new`, which also refuses an ID that is neither an Integer nor a String of 1 to 19 digits.
  * Before: `NoMethodError` or `KeyError`, or an empty `media_id` was sent.
* A missing file, or media that cannot be read, is empty, or is too large, raises `X::InvalidMedia` before any request.
  * Before: the uploaders raised `RuntimeError` "File not found" for a missing file.
  * After: rescue `X::InvalidMedia` where code rescued `RuntimeError`.
* A chunked upload that fails once initialized, at a chunk or at finalize, raises `X::ChunkedUploadFailed`.
  * Its `media` is the media the upload initialized, and its `cause` is the error that failed it.
  * Before: the request's error, such as `X::ServerError`, was raised, and the media was lost.
  * After: rescue `X::ChunkedUploadFailed`, or read `error.cause`.

The errors x-uploader raises descend from `X::Uploader::Error`, an `X::Error`:

* These are `X::Uploader::Error`s: `X::MissingMediaData`, `X::MediaProcessingFailed`, `X::MediaProcessingTimeout`, `X::ChunkedUploadFailed`, and `X::InvalidMedia`.
* `X::InvalidMediaType` descends from `X::InvalidMedia`.
  * So code that uploads user input can rescue it without rescuing the `ArgumentError` of its own mistakes.
* An `X::Error` the API raises before there is media, such as an `X::BadRequest` of the INIT request, is not an `X::Uploader::Error`, as in 0.19.
  * `rescue X::Error` catches both.

Chunk sizes are in bytes, and sizes are checked before any request:

* `chunk_size_mb:` is now `chunk_size:`, in bytes. Pass `chunk_size: 4 * 1024 * 1024` where 0.19 code passed `chunk_size_mb: 4`.
* A `chunk_size:` that is not a positive `Integer`, such as a Float, raises `ArgumentError`.
* `chunk_size:` above 5,242,880 bytes (5 MB), or one needing more than 10,000 segments, raises `ArgumentError`.
  * 0.19 sent it for the server to refuse above 8 MB.
* `chunk_size:` defaults to nil, which uploads in chunks of 4 MB, `X::Uploader::MediaUpload::DEFAULT_CHUNK_SIZE`, where 0.19 used 1 MB chunks.
  * Why: each chunk is a request a rate limit can refuse, and the API takes at most 10,000 segments, so 0.19's 1 MB chunks failed for files over 10,000 MiB.
* A file over 16 GB (17,179,869,184 bytes) raises `X::InvalidMedia` before anything is uploaded.
* An `alt_text:` that is empty or over 1,000 characters raises `ArgumentError`.
* An animated GIF over 5 MB uploads in chunks, up to 15 MB. 0.19 sent it in a single request for X to refuse.
* These raise `X::InvalidMedia` before any request, where 0.19 sent them for X to refuse:
  * An image over 5 MB.
  * A GIF over 15 MB.
  * Subtitles over 1 MB.
* A megabyte is 1,048,576 bytes. A video's limit depends on the account and is left to X, up to 16 GB.

### Timeouts

`open_timeout` defaults to 10 seconds, rather than the 60 of 0.19:

* Why: a reachable host finishes the TCP and TLS handshakes in well under a second, so 10 seconds gives up on an unresponsive host sooner.
* `read_timeout` and `write_timeout` are still 60 seconds.
* Pass `open_timeout: 60` for the old default on a network where connecting is slow.

Timeouts are checked when the client is built:

* `open_timeout`, `read_timeout`, and `write_timeout` take a finite number of seconds of at least 0, or nil for none, as in 0.19.
* Anything else, such as a String read from an environment variable, raises `ArgumentError` from `X::Client.new`.
  * Before: `Net::HTTP` raised once a request waited.

### Headers

A client takes `headers:`, which it sends with every request and stream:

* They are defaults. A header of the same name passed to a request replaces the client's.
* The client's headers replace the gem's defaults, such as its `User-Agent`.
* The gem's default `User-Agent` names the gem, Ruby, and the platform, as `x-ruby/1.0.0 ruby/3.4.0 (arm64-darwin24)`, where 0.19 sent `X-Client`.
  * Code that tells the gem's requests apart by it, such as a proxy rule, matches the new value, or sends its own with `headers:`.
* A header that carries credentials is dropped on a redirect to another origin, whether given to the client or to the request.
* A header named by a Symbol is sent with its underscores as hyphens. `content_type:` names `content-type`, so it replaces that header.
* `client.headers` names each header by a String, the way it is sent, whether it was given by a String or a Symbol.
* They are sent with the client's token requests too, the app-only bearer token, an OAuth 2.0 refresh, and the code exchange, beneath the token request's own `Authorization` and `Content-Type`.

```ruby
# 1.0
client = X::Client.new(headers: {"User-Agent" => "my-app/1.0"}, **x_credentials)
traced = client.with(headers: {"User-Agent" => "my-app/1.0", "X-Trace" => "abc"})
```

### Proxies

A client given no `proxy_url` picks the proxy for each request's scheme from the environment:

* It uses `https_proxy` for HTTPS requests, which is all these gems make, and `http_proxy` for plain HTTP.
* It connects directly to hosts listed in `no_proxy`.
* Before: `Net::HTTP` read `http_proxy` alone, whatever the scheme, so `https_proxy` was ignored.
* Set `no_proxy`, or pass a `proxy_url`, where this changes which proxy a process reaches X through.

A proxy URL can hold a user and password, so a client keeps it private:

* `proxy_url` no longer reads off `X::Client` or `X::Connection`, nor off the new `X::StreamingClient`.
* `proxy_uri`, `proxy_host`, `proxy_port`, `proxy_user`, and `proxy_pass` no longer read off a connection.
* `inspect` shows the proxy URL without its user and password, and `with` carries the proxy to a copy.
* Keep the URL you built the client with if your code needs to read it again.

### Streaming

`stream` moved from `X::Client` to `X::StreamingClient`, from `x-streaming`, which `streaming` builds from a client:

```ruby
# 0.19
client.stream("tweets/search/stream") { |post| puts post }

# 1.0
client.streaming.stream("tweets/search/stream") { |post| puts post }
```

A stream reconnects when it ends or drops:

* Before: a stream that ended returned, and one that dropped raised.
* After: it reconnects, and once it has no reconnects left raises `X::NetworkError`, whether it ended or dropped.
  * Rescue `X::NetworkError` where 0.19 code waited for `stream` to return.
* Pass `max_reconnects: 0` to `streaming` to reconnect no stream, as 0.19 did.
* Pass `on_reconnect: ->(error, wait) { ... }` to `streaming` to hear of each reconnect, or to give up with `stop`.
* To stop a stream from another thread or the trap of a signal, call `stop` on its streaming client. Each stream it stops returns nil.
  * Keep the streaming client in a variable, since each `streaming` call builds a new one.
  * The streaming client stays stopped; build another with `streaming` to stream again.
  * A block, `on_response`, or `on_reconnect` that is running finishes first.

A stream has its own `read_timeout`, 30 seconds by default:

* Before: it read with the client's 60 seconds. Pass `streaming(read_timeout: 60)` for the old timeout.
* A `read_timeout` under 25 seconds raises `ArgumentError`. Pass nil for no timeout.
  * Why: X sends a quiet stream a keep-alive every 20 seconds, so a shorter timeout would drop a live stream whenever one ran late.

Streams authenticate as the app, since the stream endpoints take app-only authentication:

* A client that signs with OAuth 1.0a fetches the app's bearer token with its API key and secret.
* A client that authenticates with OAuth 2.0 as a user streams with the app's `bearer_token`, or its `api_key` and `api_key_secret`, given beside the user's credentials.
* An OAuth 2.0 user client with neither streams as the user. X refuses it with 403, raising `X::Forbidden`.
  * The same goes for reading and changing filtered-stream rules.

`require "x"` loads `x-streaming` and gives every client `streaming`. Code that depends on `x-core` alone, and streamed with 0.19, adds `x-streaming`:

* Include its methods into the client, as `x` does.
* Or build a streaming client of a client itself:

```ruby
require "x/core"
require "x/streaming"

X::Client.include(X::Streaming::API)
client.streaming.stream("tweets/search/stream") { |post| puts post }

# or, without changing X::Client
X::StreamingClient.new(client).stream("tweets/search/stream") { |post| puts post }
```

### Errors

Some statuses raise new or different errors. `rescue X::Error` still catches them all:

* New, each an `X::ClientError`: `X::MethodNotAllowed` (405), `X::RequestTimeout` (408), `X::UnsupportedMediaType` (415), and `X::UnavailableForLegalReasons` (451).
* A 4xx or 5xx status without a class of its own raises `X::ClientError` or `X::ServerError`, rather than `X::HTTPError`.
* `X::NetworkError` wraps every network failure:
  * `IOError`, including `EOFError`.
  * `SystemCallError`, including every `Errno` error.
  * `Timeout::Error`, `Net::ProtocolError`, `Net::HTTPBadResponse`, `Zlib::Error`, `OpenSSL::SSL::SSLError`, and `SocketError`.

Error messages name the request:

* Before: the API's message alone. After: `GET /2/users/1: Could not find user`.
  * Code that matches a message against a String should allow for that prefix, or read `error.problem` instead.
* `X::TooManyRedirects` reads `GET /2/users/2: Too many redirects`, rather than `Too many redirects`.
* `error.http_method` and `error.uri` read the request on `X::HTTPError`, `X::NetworkError`, and `X::InvalidResponse`.

A successful response whose body is not JSON, such as a proxy's page, raises `X::InvalidResponse`:

* Before: it returned nil.
* `X::InvalidResponse` is an `X::HTTPError`.
* A successful response without a body still returns nil.
* `error.body` reads the body of the response when the error was built without one, once that response has been read whole.

A response body, which 0.19 read as `error.response.body`, is tagged UTF-8, where 0.19 left it binary:

* `error.body` and `error.http_response.body` can be joined with non-ASCII Strings without `Encoding::CompatibilityError`.
* Code that forced a body's encoding no longer needs to.
* A body that is not valid UTF-8 keeps its bytes. `valid_encoding?` tells it apart.

`X::TooManyRequests#reset_at`, `#reset_in`, and `#retry_after` return nil when the response does not say when the limit resets:

* Before: they returned `Time.at(0)` and 0, which retried at once.
* After: fall back to a wait of your own. X recommends a minute:

```ruby
# 0.19
sleep error.retry_after

# 1.0
sleep(error.retry_after || 60)
```

`retry_after` reads the `Retry-After` header:

* `X::HTTPError#retry_after` reads it from any refused response.
* `X::TooManyRequests#retry_after` reads it in place of the limit's reset time, which 0.19 read alone.
  * It counts seconds from when the response was sent, so the wait is right however far the local clock is off.
  * It answers for a refusal that reports no limit, such as a daily cap.
* `#reset_in` still reads the limit alone.

`X::RateLimit#retry_after` is gone:

* It was an alias for `#reset_in`, so one name would have meant two waits.
* Read a limit with `#reset_in`, and the wait a refusal asks for with `X::TooManyRequests#retry_after`:

```ruby
# 0.19
sleep error.rate_limit.retry_after

# 1.0
sleep(error.limiting_rate_limit&.reset_in || error.retry_after || 60)
```

Several readers of `X::HTTPError` are renamed or gone:

* `#error_message` and `#message_from_json_response` are gone. Read `message`.
* `#json?` is private.
* `#code` is gone. It read the status as the String `"404"`.
  * `#status` reads it as the Integer `404`, as `X::Response#status` does.
  * For the String, call `status.to_s` or read `error.http_response.code`.
* The `Net::HTTP` response is `http_response` on `X::HTTPError` and `X::InvalidResponse`, rather than `response`.
  * `X::Response#http_response` reads the same object.
* `X::RateLimit#response` is gone. Read `limit`, `remaining`, and `reset_at`, or the response of the error or `X::Response`.
* `#problem` is new, and returns the response's `X::Problem`, with `detail`, `title`, and `to_h`.

Building errors and limits changed:

* `X::HTTPError.new` no longer takes `response:`, so code that builds an error, such as a test double, raises `ArgumentError`.
  * Pass `http_response:` with the `http_method:` and `uri:` of the request.
  * Or pass `status:`, `headers:`, and `body:` without a response.
  * Or raise it with a message alone.
* `X::RateLimit.new`, which took `type:` and `response:`, is private. Read the limits of a response or an error instead.

```ruby
# 0.19
X::NotFound.new(response: response)

# 1.0
X::NotFound.new(http_response: response, http_method: :get, uri: URI("https://api.x.com/2/users/1"))
X::NotFound.new(status: 404, headers: {"content-type" => "application/json"}, body: %({"title":"Not Found Error"}))
raise X::TooManyRequests, "Too Many Requests"
```

`X::TooManyRequests#rate_limits` and `#rate_limit` mean what they mean on `X::Response`:

* `#rate_limits` reports every limit the response names. 0.19 reported only the exhausted ones.
* `#rate_limit` is the 15-minute limit. 0.19 gave the exhausted limit that resets last.
* The exhausted limits are now `#exhausted_rate_limits`.
* The one a request waits for is `#limiting_rate_limit`.
  * `reset_at` and `reset_in` read it, and so does `retry_after` without a `Retry-After` header, so code that sleeps for `retry_after` is unchanged.

```ruby
# 0.19
error.rate_limits          # the exhausted limits
error.rate_limit           # the exhausted limit that resets last

# 1.0
error.exhausted_rate_limits
error.limiting_rate_limit
```

### Version

`X::VERSION` is a String, rather than a `Gem::Version`:

* So are the `VERSION` constants of `X::Core`, `X::Uploader`, `X::Streaming`, and `X::Objects`.
* Code that logs or sends a version reads the constant itself.
* Code that compares versions calls `gem_version`, which builds the `Gem::Version`:

```ruby
# 0.19
X::VERSION >= Gem::Version.new("0.19")
X::VERSION.segments.first

# 1.0
X.gem_version >= Gem::Version.new("1.0")
X.gem_version.segments.first
```

### Internals

Internal classes and modules are private constants under `X::Core` or `X::Streaming`, so they can change within 1.x:

* `X::RequestBuilder`, `X::RedirectHandler`, `X::ResponseParser`, and `X::ClientCredentials` are under `X::Core`.
* `X::StreamParser` is `X::Streaming::StreamParser`.
* `X::Connection` is `X::Core::Connection`.
  * Build a client with the settings you gave a connection.
  * Read timeout defaults from `X::Client::DEFAULT_OPEN_TIMEOUT`, `DEFAULT_READ_TIMEOUT`, `DEFAULT_WRITE_TIMEOUT`, and `DEFAULT_KEEP_ALIVE_TIMEOUT`.
* `X::OAuth2Authenticator` has no `connection`. A client refreshes its tokens over its own connection.
* Configure the internals through the settings of `X::Client` and `X::StreamingClient`, such as `max_redirects`.
* Read their defaults from `X::Client::DEFAULT_MAX_REDIRECTS`, `DEFAULT_MAX_RATE_LIMIT_RETRIES`, `DEFAULT_MAX_RATE_LIMIT_WAIT`, and `X::StreamingClient::DEFAULT_MAX_RECONNECTS`.
* `X::Client`, `X::BearerTokenAuthenticator`, `X::OAuth2Authenticator`, `X::RateLimit`, and the errors of 0.19 keep their names, except as the table above shows.

### Removed constants

* Gone, since [simple_oauth](https://github.com/laserlemon/simple_oauth) signs requests and builds token refreshes:
  * `X::OAuthAuthenticator::OAUTH_VERSION`, `OAUTH_SIGNATURE_METHOD`, and `OAUTH_SIGNATURE_ALGORITHM`.
  * `X::OAuth2Authenticator::REFRESH_GRANT_TYPE`.
* `X::OAuth2Authenticator::TOKEN_HOST` and `TOKEN_PATH` are gone. Tokens are requested at the origin of the client's `base_url`.
* `X::MediaUploader::MAX_RETRIES` is gone. A chunk is retried up to the client's `max_retries`.
* `X::AccountUploader::MIME_TYPE_MAP` and `SUPPORTED_EXTENSIONS` are gone. A profile image or banner is checked by its signature.
* `X::AccountUploader::V1_BASE_URL` is gone. The endpoints are private, relative to the client's `base_url`.
* `X::HTTPError::JSON_CONTENT_TYPE_REGEXP` and `X::OAuth2Authenticator::EXPIRATION_BUFFER` are private.
* `X::Connection::DEFAULT_HOST` and `DEFAULT_PORT` are gone, since every request names its host.
* The gems no longer depend on `base64`, which `x` 0.19 did. Add it to your own Gemfile if you use it.
