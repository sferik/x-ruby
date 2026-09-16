# Upgrading

## From 0.19 to 1.0

Version 1.0 splits the gem into `x-core`, `x-uploader`, and `x-objects`, which `x` depends on and `require "x"` loads, and it renames or removes what version 0.19 had under old names without deprecating them first. This guide covers what code written for 0.19 needs to change. See [CHANGELOG.md](CHANGELOG.md) for everything that was added.

### Ruby

Version 1.0 requires Ruby 3.3 or later.

### Credentials

`X::Client.new` raises `ArgumentError` for credentials that do not form a complete set, where 0.19 sent requests without them. Pass a complete set: `api_key`, `api_key_secret`, `access_token`, and `access_token_secret` for OAuth 1.0a; `client_id`, `access_token`, and `refresh_token`, with the `client_secret` of a confidential client, for OAuth 2.0; `bearer_token`; or `api_key` and `api_key_secret` alone to authenticate as the app. An OAuth 2.0 access token that is not refreshed is a `bearer_token`.

The authenticators and `X::RateLimit` are read-only. Change a credential with the setters of `X::Client`:

```ruby
# 0.19
client.authenticator.access_token = "new_token"

# 1.0
client.access_token = "new_token"
client.update_credentials(access_token: "new_token", access_token_secret: "new_secret") # both at once
```

A client authenticates with the first complete set of credentials it holds, so a setter that clears a credential no longer keeps the authenticator it had: `client.bearer_token = nil` sends requests without credentials, and `client.access_token_secret = nil` authenticates as the app when the client holds an API key and secret. `update_credentials` changes several credentials before the client builds its authenticator again, and raises `ArgumentError`, leaving the client as it was, for credentials that do not form a complete set.

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

`X::Uploader::Validator` is private API, which the uploaders validate their arguments with, and the MIME type and media category tables of `X::Uploader::Media`, such as `MIME_TYPE_MAP`, are private constants. Pass a file to `upload`, which raises `Errno::ENOENT` for a missing file and `ArgumentError` for an invalid category.

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
```

`upload` infers the media category from the file, and still takes `media_category:`. `upload_binary` takes the content as a positional argument and requires `media_category:`, and `await_processing` and `await_processing!` take the media as one.

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

A 4xx or 5xx status without an error class of its own raises `X::ClientError` or `X::ServerError` rather than `X::HTTPError`, and `X::NetworkError` wraps `IOError`, which includes `EOFError`, along with `SocketError`, `Net::WriteTimeout`, `Net::HTTPBadResponse`, `Errno::ETIMEDOUT`, `Errno::EHOSTUNREACH`, `Errno::ENETUNREACH`, and `Errno::EPIPE`. Rescuing `X::Error` still catches them all.

A successful response whose body is not JSON, such as the page of a proxy, raises `X::InvalidResponse`, an `X::Error`, rather than returning nil. A successful response without a body still returns nil.

`X::TooManyRequests#reset_at`, `#reset_in`, and `#retry_after` return nil when the response does not say when the limit resets, where 0.19 returned `Time.at(0)` and 0, which retried at once. X recommends waiting a minute instead:

```ruby
# 0.19
sleep error.retry_after

# 1.0
sleep(error.retry_after || 60)
```

`X::HTTPError#error_message`, `#message_from_json_response`, and `#json?` are private. Read `message` instead. `X::HTTPError#status` reads the status as an Integer, beside `code`.

### Removed constants

`X::OAuthAuthenticator::OAUTH_SIGNATURE_ALGORITHM` and `X::OAuth2Authenticator::REFRESH_GRANT_TYPE` are gone, since [simple_oauth](https://github.com/laserlemon/simple_oauth) signs requests and builds token refreshes now. `x-core` no longer depends on `base64`, so add it to your own Gemfile if you use it.
