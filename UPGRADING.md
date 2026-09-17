# Upgrading

## From 0.19 to 1.0

Version 1.0 splits the gem into `x-core`, `x-uploader`, and `x-objects`, which `x` depends on and `require "x"` loads, and it renames or removes what version 0.19 had under old names without deprecating them first. This guide covers what code written for 0.19 needs to change. See [CHANGELOG.md](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) for everything that was added.

### Ruby

Version 1.0 requires Ruby 3.4 or later.

### Credentials

`X::Client.new` raises `ArgumentError` for credentials that do not form a complete set, where 0.19 sent requests without them. Pass a complete set: `api_key`, `api_key_secret`, `access_token`, and `access_token_secret` for OAuth 1.0a; `client_id`, `access_token`, and `refresh_token`, with the `client_secret` of a confidential client, for OAuth 2.0; `bearer_token`; or `api_key` and `api_key_secret` alone to authenticate as the app. An OAuth 2.0 access token that is not refreshed is a `bearer_token`. Every credential must belong to a complete set, so a credential of a set that is not complete, such as a `client_id` or an `api_key` beside a `bearer_token`, raises `ArgumentError` rather than being ignored; leave it out. A client may hold several complete sets, such as the bearer token of an app beside its API key and secret, and authenticates with the first of them, in the order above, and an `expires_at` is allowed beside any credentials.

The authenticators and `X::RateLimit` are read-only. Change a credential with the setters of `X::Client`:

```ruby
# 0.19
client.authenticator.access_token = "new_token"

# 1.0
client.access_token = "new_token"
client.update_credentials(access_token: "new_token", access_token_secret: "new_secret") # both at once
```

A client authenticates with the first complete set of credentials it holds, so a setter that clears a credential no longer keeps the authenticator it had: `client.bearer_token = nil` sends requests without credentials, and `client.access_token_secret = nil` authenticates as the app when the client holds an API key and secret. `update_credentials` changes several credentials before the client builds its authenticator again, and raises `ArgumentError`, leaving the client as it was, for credentials that do not form a complete set.

### Requests

An endpoint that begins with a slash is relative to the base URL, like one without, where 0.19 resolved it against the host and dropped the path of the base URL, such as the `/2/` of the API version. Pass a whole URL, or derive a client with `copy`, to reach another version of the API:

```ruby
# 0.19
client.get("/1.1/account/settings.json")

# 1.0
client.copy(base_url: "https://api.x.com/1.1/").get("account/settings.json")
client.get("https://api.x.com/1.1/account/settings.json")
```

A request is sent once. In 0.19, `Net::HTTP` sent a GET, PUT, or DELETE request again by itself after a timeout or a dropped connection, with the OAuth 1.0a nonce and signature of the first attempt. Version 1.0 raises `X::NetworkError` instead, so rescue it to send a request again.

### Renamed classes

| 0.19 | 1.0 |
| --- | --- |
| `X::OAuthAuthenticator` | `X::OAuth1Authenticator` |
| `X::ConnectionException` | `X::Conflict` |
| `X::InvalidMediaType` | `X::Uploader::InvalidMediaType` |
| `X::MediaUploader` | `X::Uploader::Media` |
| `X::AccountUploader` | `X::Uploader::Account` |
| `X::MediaUploadValidator` | `X::Uploader::Validator` |

Remove `require "x/media_uploader"` and `require "x/account_uploader"`. `require "x"` loads the uploaders.

`X::Uploader::Validator` is private API, which the uploaders validate their arguments with, and the MIME type and media category tables of `X::Uploader::Media` are private constants: `MIME_TYPES`, `MIME_TYPE_MAP`, and the MIME type constants, such as `GIF_MIME_TYPE`, `MP4_MIME_TYPE`, and `SUBRIP_MIME_TYPE`. `PROCESSING_INFO_STATES` is gone, since `X::Uploader::UploadedMedia#processing?` tells whether media is still processing. The media category constants, such as `TWEET_IMAGE`, and `BYTES_PER_MB` remain public. Pass a file to `upload`, which raises `Errno::ENOENT` for a missing file and `ArgumentError` for an invalid category, or infer a type with `infer_media_type`.

### Uploads

The uploaders take the file, content, or media as their first argument, and the client as a keyword:

```ruby
# 0.19
media = X::MediaUploader.upload(client:, file_path: "cat.jpg", media_category: "tweet_image")
video = X::MediaUploader.chunked_upload(client:, file_path: "cat.mp4", media_category: "tweet_video")
X::MediaUploader.await_processing!(client:, media: video)
X::AccountUploader.update_profile_image(client:, file_path: "avatar.png")
X::AccountUploader.upload_profile_image_binary(client:, content:)
X::AccountUploader.upload_profile_banner_binary(client:, content:)

# 1.0
media = X::Uploader::Media.upload("cat.jpg", client:)
video = X::Uploader::Media.upload("cat.mp4", client:) # uploads in chunks and awaits processing
X::Uploader::Account.update_profile_image("avatar.png", client:)
X::Uploader::Account.update_profile_image_binary(content, client:)
X::Uploader::Account.update_profile_banner_binary(content, client:)

# 1.0, as methods of a client, which require "x" adds
media = client.upload_media("cat.jpg")
client.update_profile_image("avatar.png")
```

`upload` infers the media category from the file, and still takes `media_category:`. No upload method takes `boundary:`, since each upload generates the boundary of its multipart body. `upload_binary` takes the content as a positional argument and requires `media_category:`, and `await_processing` and `await_processing!` take the media as one: the response of an upload, or a media identifier. Every method that takes a file takes a `String` or a `Pathname`. A class that includes `X::Uploader::Media` gains its public methods alone: the private methods it used to gain, such as `init`, `append`, and `construct_upload_body`, belong to private modules now.

`upload`, `upload_binary`, `chunked_upload`, `await_processing`, and `await_processing!` return an `X::Uploader::UploadedMedia` rather than a Hash. It is frozen, and reads as the Hash did with `[]`, `fetch`, `dig`, and `key?`, so `media["id"]` and `media.dig("processing_info", "state")` work unchanged, and `to_h` returns the Hash for code that needs one, such as a comparison with a Hash or `media.merge(...)`. It also reads `id`, as an Integer, `media_key`, `size`, `expires_at`, `state`, `processing?`, `failed?`, and `ready?`. `upload` returns the processing status of media that X processes, such as a video or an animated GIF, rather than the response of the upload; both hold the media's identifier. The other uploaders return Hashes and Arrays whatever the `default_object_class` and `default_array_class` of the client, where 0.19 parsed their responses with the client's classes.

`infer_media_type` returns the type the category takes that the file's extension names, such as `video/quicktime` for `clip.mov` uploaded as `tweet_video`, where 0.19 returned `video/mp4` for every video, and it returns `text/srt` for SubRip subtitles, where 0.19 returned `application/x-subrip`.

`await_processing!` raises `X::Uploader::MediaProcessingFailed` rather than `RuntimeError`, and `await_processing` raises `X::Uploader::MediaProcessingTimeout` after ten minutes rather than waiting forever. Both are `X::Error`s. A file that does not exist raises `Errno::ENOENT`.

### Streaming

`stream` moved from `X::Client` to `X::StreamingClient`, which `streaming` builds from a client:

```ruby
# 0.19
client.stream("tweets/search/stream") { |post| puts post }

# 1.0
client.streaming.stream("tweets/search/stream") { |post| puts post }
```

A stream reconnects when it ends or drops, where 0.19 returned or raised. Pass `max_reconnects: 0` to `streaming` to keep the old behavior.

### Errors

A 4xx or 5xx status without an error class of its own raises `X::ClientError` or `X::ServerError` rather than `X::HTTPError`, and `X::NetworkError` wraps every network failure: `IOError`, which includes `EOFError`, `SystemCallError`, which includes every `Errno` error, `Timeout::Error`, `Net::ProtocolError`, `Net::HTTPBadResponse`, `Zlib::Error`, `OpenSSL::SSL::SSLError`, and `SocketError`. Rescuing `X::Error` still catches them all.

A successful response whose body is not JSON, such as the page of a proxy, raises `X::InvalidResponse`, an `X::Error`, rather than returning nil. A successful response without a body still returns nil.

`X::TooManyRequests#reset_at`, `#reset_in`, and `#retry_after` return nil when the response does not say when the limit resets, where 0.19 returned `Time.at(0)` and 0, which retried at once. X recommends waiting a minute instead:

```ruby
# 0.19
sleep error.retry_after

# 1.0
sleep(error.retry_after || 60)
```

`X::HTTPError#error_message`, `#message_from_json_response`, and `#json?` are private. Read `message` instead. `X::HTTPError#status` reads the status as an Integer, beside `code`.

### Internals

`X::RequestBuilder`, `X::RedirectHandler`, `X::ResponseParser`, `X::StreamParser`, `X::RateLimitHandler`, and `X::ReconnectHandler` are private API, which can change within 1.x; configure them through the settings of `X::Client` and `X::StreamingClient`, such as `max_redirects`. `X::RedirectHandler#handle` no longer takes `base_url:`, since a relative redirect resolves against the request it redirects.

### Removed constants

`X::OAuthAuthenticator::OAUTH_VERSION`, `OAUTH_SIGNATURE_METHOD`, and `OAUTH_SIGNATURE_ALGORITHM`, and `X::OAuth2Authenticator::REFRESH_GRANT_TYPE` are gone, since [simple_oauth](https://github.com/laserlemon/simple_oauth) signs requests and builds token refreshes now. `X::OAuth2Authenticator::TOKEN_HOST` and `TOKEN_PATH` are now one constant, `TOKEN_URL`. `X::MediaUploader::MAX_RETRIES` is gone, since a chunk is retried by `X::Uploader::Chunks`, which is private API, and `X::AccountUploader::MIME_TYPE_MAP` is gone, since nothing read it. `x-core` no longer depends on `base64`, so add it to your own Gemfile if you use it.
