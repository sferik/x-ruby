# Upgrading

## From 0.19 to 1.0

Version 1.0 splits the gem into `x-core`, `x-uploader`, and `x-objects`, which `x` depends on and `require "x"` loads, and it renames or removes what version 0.19 had under old names without deprecating them first. This guide covers what code written for 0.19 needs to change. See [CHANGELOG.md](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) for everything that was added.

### Ruby

Version 1.0 requires Ruby 3.4 or later.

### Credentials

`X::Client.new` raises `ArgumentError` for credentials that do not form a complete set, where 0.19 sent requests without them. Pass a complete set: `api_key`, `api_key_secret`, `access_token`, and `access_token_secret` for OAuth 1.0a; `client_id`, `access_token`, and `refresh_token`, with the `client_secret` of a confidential client, for OAuth 2.0; `bearer_token`; or `api_key` and `api_key_secret` alone to authenticate as the app. An OAuth 2.0 access token that is not refreshed is a `bearer_token`. Every credential must belong to a complete set, so a credential of a set that is not complete, such as a `client_id` or an `api_key` beside a `bearer_token`, raises `ArgumentError` rather than being ignored; leave it out. A client may hold several complete sets, such as the bearer token of an app beside its API key and secret, and authenticates with the first of them, in the order above, and an `expires_at` is allowed beside any credentials. A credential that is an empty String raises `ArgumentError` too, from `X::Client.new`, since an environment variable that is not set is often read as one, as `ENV.fetch("X_BEARER_TOKEN", "")` reads it, and 0.19 sent the empty credential for the API to refuse.

A client, its authenticators, and `X::RateLimit` are read-only. A client keeps the credentials and settings it was built with for as long as it lives, so a request never signs with a mix of old and new credentials, and never runs against a setting another thread is halfway through changing. `with` derives a client that differs, taking anything `X::Client.new` takes and checking it the same way:

```ruby
# 0.19
client.authenticator.access_token = "new_token"

# 1.0
rotated = client.with(access_token: "new_token", access_token_secret: "new_secret")
```

Each option a client has is an option of `with`, where 0.19 had a setter for it: `base_url=`, `default_array_class=`, `default_object_class=`, `open_timeout=`, `read_timeout=`, `write_timeout=`, `debug_output=`, `proxy_url=`, `max_redirects=`, and the setter of each credential are gone from `X::Client`, the setters of the credentials and `connection=` from the authenticators, and `type=` and `response=` from `X::RateLimit`. Derive a client instead, as `client.with(read_timeout: 30)`.

The credentials of a copy must form a complete set of their own, so clearing one that leaves an incomplete set raises `ArgumentError` rather than quietly authenticating as someone else. A client and the copies `with` derives from it share one authenticator while they hold the same OAuth 2.0 credentials, so a refresh by any of them reaches all, and X accepts a refresh token once.

A client refreshes an OAuth 2.0 access token itself, when the `expires_at` it was given passes or X rejects the token, where 0.19 never refreshed one. X issues a new refresh token with each refresh and accepts the old one no more, so store the tokens of each refresh from `on_token_refresh`, as below, or the refresh token an application stored stops working.

A client reveals no credential that is a secret, and neither does the authenticator it hands out. On a client, `api_key_secret`, `access_token`, `access_token_secret`, `bearer_token`, `client_secret`, and `refresh_token` are private, where 0.19 read each of them off a client; on an authenticator, `api_key_secret`, `access_token_secret`, `client_secret`, and the `bearer_token` of an `X::BearerTokenAuthenticator` or an `X::AppOnlyAuthenticator` are private too, so `client.authenticator` is no longer a way around the client. Nothing that reflects over either reads a secret out of it, as `inspect` reveals none. `api_key` and `client_id` remain public on a client, since neither is a secret, beside `expires_at`, which is new, as do `access_token` and `refresh_token` on an authenticator, which is how the tokens of a refresh are stored. Two authenticators are told apart with `X::OAuth2Authenticator#same_credentials?`, and the user an OAuth 1.0a access token names is read with `X::Authenticator#user_id` rather than out of the token. Read the tokens of a refresh from the authenticator the `on_token_refresh` hook is passed, and carry credentials to another client with `with`:

```ruby
# 0.19
store(client.access_token, client.refresh_token)

# 1.0
X::Client.new(**credentials, on_token_refresh: ->(auth) { store(auth.access_token, auth.refresh_token, auth.expires_at) })
```

An OAuth 2.0 authenticator refreshes its tokens at once with `refresh!`, where 0.19 called it `refresh_token!`, which sat beside the `refresh_token` reader as though it were its bang form. It returns the authenticator, which holds the new tokens, rather than the Hash of the token response:

```ruby
# 0.19
store(client.authenticator.refresh_token!["refresh_token"])

# 1.0
store(client.authenticator.refresh!.refresh_token)
```

### Requests

An endpoint that begins with a slash is relative to the base URL, like one without, where 0.19 resolved it against the host and dropped the path of the base URL, such as the `/2/` of the API version. Pass a whole URL, or derive a client with `with`, to reach another version of the API:

```ruby
# 0.19
client.get("/1.1/account/settings.json")

# 1.0
client.with(base_url: "https://api.x.com/1.1/").get("account/settings.json")
client.get("https://api.x.com/1.1/account/settings.json")
```

The default `base_url` is `https://api.x.com/2/`, where 0.19 defaulted to `https://api.twitter.com/2/`, so pass whole URLs on `api.x.com`, or a `base_url` on `api.twitter.com`, since a whole URL of another origin carries none of the client's credentials. An endpoint is signed and sent with the client's `Authorization` header only when it names the scheme, host, and port of the `base_url`, as the API version above does; an endpoint, or a stream, of any other origin is sent without it, and without any `Authorization`, `Cookie`, or `Proxy-Authorization` header of the client or the request, where 0.19 signed a request for whatever host its endpoint named. A redirect off the origin drops them too, where 0.19 signed the first redirect for whatever host it named. To reach another host with credentials of its own, build a client for it with its own `base_url`.

`Net::HTTP` no longer sends a request again by itself. In 0.19, it sent a GET, PUT, or DELETE request again after a timeout or a dropped connection, with the OAuth 1.0a nonce and signature of the first attempt, and a 5xx response raised at once. Version 1.0 sends a GET, PUT, or DELETE request again itself after an `X::NetworkError` or an `X::ServerError`, `max_retries` times, twice by default, signing each attempt afresh and waiting as long as a `Retry-After` header asks; pass `max_retries: 0` to raise at once, as code with a retry loop of its own may want. See the retries in [README.md](https://github.com/sferik/x-ruby/blob/main/README.md).

### Renamed classes

| 0.19 | 1.0 |
| --- | --- |
| `X::OAuthAuthenticator` | `X::OAuth1Authenticator` |
| `X::ConnectionException` | `X::Conflict` |
| `X::MediaUploader` | `X::Uploader::MediaUpload` |
| `X::AccountUploader` | `X::Uploader::Account` |

Remove `require "x/media_uploader"` and `require "x/account_uploader"`. `require "x"` loads the uploaders.

`X::MediaUploadValidator` is gone, with no public replacement: the uploaders validate their arguments themselves, raising `ArgumentError` for an invalid category, and the categories are the constants of `X::Uploader::MediaUpload`, such as `TWEET_IMAGE`. `X::Uploader::Validator`, which they validate with, is a private constant, as are `X::Uploader::Chunks`, `X::Uploader::Multipart`, and `X::Uploader::Utils`, which they upload and read files with, and the MIME type and media category tables of `X::Uploader::MediaUpload` are private constants: `MIME_TYPES`, `MIME_TYPE_MAP`, and the MIME type constants, such as `GIF_MIME_TYPE`, `MP4_MIME_TYPE`, and `SUBRIP_MIME_TYPE`. `PROCESSING_INFO_STATES` is gone, since `X::UploadedMedia#processing?` tells whether media is still processing. The media category constants, such as `TWEET_IMAGE`, and `BYTES_PER_MB` remain public. Pass a file to `upload`, which raises `Errno::ENOENT` for a missing file and `ArgumentError` for an invalid category, or infer a type with `infer_media_type`.

### Uploads

The uploaders take the file, content, or media as their first argument, and the client as a keyword, and `upload_profile_image_binary` and `upload_profile_banner_binary` are `update_profile_image_binary` and `update_profile_banner_binary`, the binary forms of `update_profile_image` and `update_profile_banner`:

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
X::Uploader::Account.update_profile_image_binary(content, client:)
X::Uploader::Account.update_profile_banner_binary(content, client:)

# 1.0, as methods of a client, which require "x" adds
media = client.upload_media("cat.jpg")
client.update_profile_image("avatar.png")
```

`upload` infers the media category from the media, and still takes `media_category:`. No upload method takes `boundary:`, since each upload generates the boundary of its multipart body. `upload_binary` takes the content as a positional argument and requires `media_category:`, and `await_processing` and `await_processing!` take the media as one: the response of an upload, or a media identifier. A class that includes `X::Uploader::MediaUpload` gains its public methods alone: the private methods it used to gain, such as `init`, `append`, and `construct_upload_body`, belong to private modules now.

`upload`, `chunked_upload`, and `infer_media_type` take media as a path or as an IO open on it, where 0.19 took a path alone, as do the new `chunked_upload?`, `infer_media_category`, and `X::Uploader::Gif.animated?`. Media given as a `String` or a `Pathname` is read from the file it names, and media given as a `File` or a `Tempfile` through that IO, each a chunk at a time, so media of any size uploads without being held in memory; media given as any other IO, such as a `StringIO`, is read to its end and held. The media category of media that names no file is read from the bytes it begins with, so `client.upload_media(StringIO.new(png))` uploads an image, and media whose signature names no type, such as SubRip subtitles, raises `X::InvalidMediaType` unless `media_category:` says what it is. The profile image and banner of `X::Uploader::Account` still take a path alone, whose extension must be `gif`, `jpg`, `jpeg`, or `png`, or `X::InvalidMediaType` is raised, and `update_profile_image_binary` and `update_profile_banner_binary` take the bytes. They are posted with the client they are given, with its credentials, to the API v1.1 at the host of its `base_url`, where 0.19 built a client of its own for `https://api.x.com/1.1/` from the OAuth 1.0a credentials.

A client has no `upload_media_binary`, since `upload_media` takes the media held in memory and infers its category. `X::Uploader::MediaUpload.upload_binary`, which 0.19 had as `X::MediaUploader.upload_binary`, remains for content whose category is known and which is to be uploaded in a single request without awaiting processing. It raises `ArgumentError` for the category of a video, or of subtitles, which the API takes in chunks alone, where 0.19 sent the request for the API to refuse:

```ruby
# 0.19
X::MediaUploader.upload_binary(client:, content:, media_category: "tweet_image")

# 1.0
client.upload_media(StringIO.new(content))                            # the category read from the signature
client.upload_media(StringIO.new(content), media_category: "tweet_image")
X::Uploader::MediaUpload.upload_binary(content, client:, media_category: "tweet_image")
```

`upload`, `upload_binary`, `chunked_upload`, `await_processing`, and `await_processing!` return an `X::UploadedMedia` rather than a Hash. It is frozen, and reads as the Hash did with `[]`, `fetch`, which takes a default value and a block as `Hash#fetch` does, `dig`, and `key?`, so `media["size"]` and `media.dig("processing_info", "state")` work unchanged, and `to_h` returns the Hash for code that needs one, such as a comparison with a Hash or `media.merge(...)`. It also reads `id`, `media_key`, `bytesize`, the byte count that `media["size"]` holds, `expires_at`, `state`, `processing?`, `failed?`, and `ready?`, and writes itself as its response with `as_json` and `to_json`. `media.id` reads the identifier as an Integer, while `media["id"]`, `media.to_h`, and the JSON of `as_json` and `to_json` hold the String the API gave, as the Hash of 0.19 did. Nothing else changes: `media_ids:` sends each identifier as a String, as it did. `upload` returns the processing status of media that X processes, such as a video or an animated GIF, rather than the response of the upload; both hold the media's identifier. The other uploaders return Hashes and Arrays whatever the `default_object_class` and `default_array_class` of the client, where `X::MediaUploader` parsed its responses with the client's classes.

`infer_media_type` returns the type the category takes that the file's extension names, such as `video/quicktime` for `clip.mov` uploaded as `tweet_video`, where 0.19 returned `video/mp4` for every video, and it returns `text/srt` for SubRip subtitles, where 0.19 returned `application/x-subrip`.

`await_processing!` raises `X::MediaProcessingFailed` rather than `RuntimeError`, and `await_processing` raises `X::MediaProcessingTimeout` after ten minutes rather than waiting forever; pass `processing_timeout: Float::INFINITY` to wait for as long as processing takes, as 0.19 did, since a `processing_timeout` of nil raises `ArgumentError` before any request. Media that holds no identifier, such as nil, and a response of an upload that describes no media raise `X::MissingData`, where 0.19 raised `NoMethodError` or `KeyError`, or sent an empty `media_id`. All three descend from `X::Uploader::Error`, an `X::Error`, so `rescue X::Uploader::Error` catches the failures of an upload alone. A file that does not exist raises `Errno::ENOENT`, and an empty one `ArgumentError`, before any request.

`chunk_size_mb:` is nil by default, which derives the chunk size from the size of the file, since the API numbers no more than 1,000 segments and the 1 MB chunks of 0.19 refused a file larger than 1,000 MiB after uploading about a gigabyte of it. A file of a gigabyte or less still uploads in 1 MB chunks. Passing a `chunk_size_mb:` that would need more than 1,000 segments raises `ArgumentError` before anything is uploaded, as does an `alt_text:` that is empty or longer than the 1,000 characters the API takes. An animated GIF larger than 5 MB uploads in chunks, which the API takes up to 15 MB of, where 0.19 sent it in a single request for X to refuse.

### Timeouts

`open_timeout` defaults to 10 seconds rather than the 60 of 0.19. Opening a connection is a TCP handshake and a TLS one, which a reachable host finishes in well under a second, so the shorter timeout gives up on a host that is not answering rather than hold a request for a minute. `read_timeout` and `write_timeout` are 60 seconds still, since an endpoint may be slow to answer. Pass `open_timeout: 60` for the old default, on a network where opening a connection is slow.

### Headers

A client takes `headers`, which it sends with every request and every stream it makes. They are defaults: a header of the same name passed to a request is sent in place of the client's, and each of the client's is sent in place of a default of the gem, such as its `User-Agent`. A header that carries credentials is dropped by a redirect to another origin, whether it was given to the client or to the request.

```ruby
# 1.0
client = X::Client.new(headers: {"User-Agent" => "my-app/1.0"}, **x_credentials)
traced = client.with(headers: {"User-Agent" => "my-app/1.0", "X-Trace" => "abc"})
```

### Proxies

A client that is given no `proxy_url` takes the proxy the environment names for the scheme of each request, in `https_proxy` for the HTTPS requests these gems make or `http_proxy` for plain HTTP, and reaches the hosts that `no_proxy` names directly. In 0.19, `Net::HTTP` resolved the proxy, and it reads `http_proxy` alone whatever the scheme, so a proxy named in `https_proxy` was ignored and one named in `http_proxy` carried every request. Set `no_proxy`, or pass a `proxy_url`, where that changes which proxy a process reaches X through.

A proxy URL can hold the user and password of the proxy, so a client keeps it to itself, as it keeps its credentials: `proxy_url` no longer reads off `X::Client` or `X::Connection`, nor off the `X::StreamingClient` new in 1.0, and `proxy_uri`, `proxy_host`, `proxy_port`, `proxy_user`, and `proxy_pass` no longer read off a connection. `inspect` shows the proxy URL without its user and password, and `with` carries the proxy to a copy of the client. Keep the URL you built the client with where your code needs to read it again.

### Streaming

`stream` moved from `X::Client` to `X::StreamingClient`, which `streaming` builds from a client:

```ruby
# 0.19
client.stream("tweets/search/stream") { |post| puts post }

# 1.0
client.streaming.stream("tweets/search/stream") { |post| puts post }
```

A stream reconnects when it ends or drops, where 0.19 returned or raised. Pass `max_reconnects: 0` to `streaming` to keep the old behavior. A stream reads with a `read_timeout` of its own, 30 seconds by default, where 0.19 read with the 60 of the client; pass `streaming(read_timeout: 60)` for the old one.

A stream authenticates as the app, which the stream endpoints take alone: a client that signs with OAuth 1.0a fetches the app's bearer token with its API key and secret, and a client that authenticates with OAuth 2.0 as a user streams with the app's `bearer_token`, or its `api_key` and `api_key_secret`, given beside the user's credentials, and raises `X::UnsupportedOperation` before it connects when it holds neither.

### Errors

`X::MethodNotAllowed` (405), `X::RequestTimeout` (408), `X::UnsupportedMediaType` (415), and `X::UnavailableForLegalReasons` (451) are new, and each is an `X::ClientError`, as the statuses beside them are. A 4xx or 5xx status without an error class of its own raises `X::ClientError` or `X::ServerError` rather than `X::HTTPError`, and `X::NetworkError` wraps every network failure: `IOError`, which includes `EOFError`, `SystemCallError`, which includes every `Errno` error, `Timeout::Error`, `Net::ProtocolError`, `Net::HTTPBadResponse`, `Zlib::Error`, `OpenSSL::SSL::SSLError`, and `SocketError`. Rescuing `X::Error` still catches them all.

The message of an error names the request it was raised for, as `GET /2/users/1: Could not find user` does, where 0.19 gave the message of the API alone, so code that matches a message against a String matches it behind that name, or reads `error.problem` instead. `error.http_method` and `error.uri` read the request themselves, on `X::HTTPError`, `X::NetworkError`, and `X::InvalidResponse` alike.

A successful response whose body is not JSON, such as the page of a proxy, raises `X::InvalidResponse`, an `X::Error`, rather than returning nil. A successful response without a body still returns nil.

`X::TooManyRequests#reset_at`, `#reset_in`, and `#retry_after` return nil when the response does not say when the limit resets, where 0.19 returned `Time.at(0)` and 0, which retried at once. X recommends waiting a minute instead:

```ruby
# 0.19
sleep error.retry_after

# 1.0
sleep(error.retry_after || 60)
```

`X::HTTPError#retry_after` reads the `Retry-After` header of any response the API refused, and `X::TooManyRequests#retry_after` reads it in place of the reset time of the limit that 0.19 read alone. The header counts the seconds from when the response was sent, so the wait is right however far the clock of the machine is from the API's, and it answers for a refusal that reports no limit, such as a daily cap. `#reset_in` still reads the limit alone.

`X::RateLimit#retry_after` is gone. It was an alias for `#reset_in`, and it kept that meaning while `X::TooManyRequests#retry_after` gained the header, so one name answered a request with two waits. Read a limit with `#reset_in`, and the wait a refusal asks for with `X::TooManyRequests#retry_after`:

```ruby
# 0.19
sleep error.rate_limit.retry_after

# 1.0
sleep(error.limiting_rate_limit&.reset_in || error.retry_after || 60)
```

`X::HTTPError#error_message` and `#message_from_json_response` are gone, and `#json?` is private. Read `message` instead. `X::HTTPError#code`, which read the status as the String `"404"` that Net::HTTP reads, is gone; `#status` reads it as the Integer `404`, as `X::Response#status` does. Where the String is wanted, call `to_s` on the status, or read `error.http_response.code`. The Net::HTTP response of a failed request is `http_response` on `X::HTTPError`, `X::InvalidResponse`, and `X::RateLimit`, where 0.19 called it `response`, so that one name means one thing across the gems: `X::Response#http_response` reads the same object. `X::HTTPError#problem` is new, and answers the `X::Problem` of the response, such as `problem.detail` and `problem.title`, and `problem.to_h` is its Hash.

`X::TooManyRequests#rate_limits` reports every rate limit the response names, where 0.19 reported only the ones with no requests left, and `#rate_limit` is the 15-minute limit, where 0.19 gave the exhausted limit that resets last. Both now mean what they mean on `X::Response`. The exhausted limits are `#exhausted_rate_limits`, and the one a request waits for is `#limiting_rate_limit`, which `reset_at` and `reset_in` still read, as does `retry_after` for a refusal without a `Retry-After` header, so code that sleeps for `retry_after` is unchanged:

```ruby
# 0.19
error.rate_limits          # the exhausted limits
error.rate_limit           # the exhausted limit that resets last

# 1.0
error.exhausted_rate_limits
error.limiting_rate_limit
```

### Version

`X::VERSION` is a String, where 0.19 held a `Gem::Version` in it, as are the `VERSION` of `X::Core`, `X::Uploader`, and `X::Objects`. Code that reads a version as a String, to log it or to send it somewhere, now reads the constant itself; code that compares one release with another calls `gem_version`, which builds the `Gem::Version` the constant used to hold.

```ruby
# 0.19
X::VERSION >= Gem::Version.new("0.19")
X::VERSION.segments.first

# 1.0
X.gem_version >= Gem::Version.new("1.0")
X.gem_version.segments.first
```

### Internals

The classes and modules that are internal to `x-core` are named under `X::Core` rather than directly under `X`, so that the flat namespace holds the interface alone and they can change within 1.x: `X::RequestBuilder` is `X::Core::RequestBuilder`, and so are `X::RedirectHandler`, `X::ResponseParser`, `X::StreamParser`, and the `X::ClientCredentials` mixin of the client, the internals of 0.19, beside the internals that are new. `X::Client`, the authenticators, `X::Connection`, `X::RateLimit`, and every error of 0.19 keep the names they had. Configure the internals through the settings of `X::Client` and `X::StreamingClient`, such as `max_redirects`, and read their defaults from `X::Client::DEFAULT_MAX_REDIRECTS`, `X::Client::DEFAULT_MAX_RATE_LIMIT_RETRIES`, `X::Client::DEFAULT_MAX_RATE_LIMIT_WAIT`, and `X::StreamingClient::DEFAULT_MAX_RECONNECTS`, rather than from the handlers. `X::RedirectHandler#handle` no longer takes `base_url:`, since a relative redirect resolves against the request it redirects.

### Removed constants

`X::OAuthAuthenticator::OAUTH_VERSION`, `OAUTH_SIGNATURE_METHOD`, and `OAUTH_SIGNATURE_ALGORITHM`, and `X::OAuth2Authenticator::REFRESH_GRANT_TYPE` are gone, since [simple_oauth](https://github.com/laserlemon/simple_oauth) signs requests and builds token refreshes now. `X::OAuth2Authenticator::TOKEN_HOST` and `TOKEN_PATH` are now one constant, `TOKEN_URL`. `X::MediaUploader::MAX_RETRIES` is gone, since a chunk is sent again up to the `max_retries` of the client, as an idempotent request is, and `X::AccountUploader::MIME_TYPE_MAP` is gone, since nothing read it. `X::Uploader::Account::SUPPORTED_EXTENSIONS`, which 0.19 named `X::AccountUploader::SUPPORTED_EXTENSIONS`, is a private constant, beside the endpoints it posts to, which 0.19 named in the public `X::AccountUploader::V1_BASE_URL` and which are relative to the base URL of the client now. `X::HTTPError::JSON_CONTENT_TYPE_REGEXP`, `X::Connection::NETWORK_ERRORS`, and `X::OAuth2Authenticator::EXPIRATION_BUFFER` are private constants, which can change within 1.x, and `X::Connection::DEFAULT_HOST` and `DEFAULT_PORT` are gone, since every request names its host. The gems no longer depend on `base64`, which `x` 0.19 did, so add it to your own Gemfile if you use it.
