# Upgrading

## From 0.19 to 1.0

Version 1.0 splits the gem into `x-core`, `x-uploader`, and `x-objects`, which `x` depends on and `require "x"` loads, and it renames or removes what version 0.19 had under old names without deprecating them first. This guide covers what code written for 0.19 needs to change. See [CHANGELOG.md](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) for everything that was added.

### Ruby

Version 1.0 requires Ruby 3.4 or later.

### Credentials

`X::Client.new` raises `ArgumentError` for credentials that do not form a complete set, where 0.19 sent requests without them. Pass a complete set: `api_key`, `api_key_secret`, `access_token`, and `access_token_secret` for OAuth 1.0a; `client_id`, `access_token`, and `refresh_token`, with the `client_secret` of a confidential client, for OAuth 2.0; `bearer_token`; or `api_key` and `api_key_secret` alone to authenticate as the app. An OAuth 2.0 access token that is not refreshed is a `bearer_token`. Every credential must belong to a complete set, so a credential of a set that is not complete, such as a `client_id` or an `api_key` beside a `bearer_token`, raises `ArgumentError` rather than being ignored; leave it out. A client may hold several complete sets, such as the bearer token of an app beside its API key and secret, and authenticates with the first of them, in the order above, and an `expires_at` is allowed beside any credentials. A credential that is an empty String raises `ArgumentError` too, from `X::Client.new` and from the setters, since an environment variable that is not set is often read as one, as `ENV.fetch("X_BEARER_TOKEN", "")` reads it, and 0.19 sent the empty credential for the API to refuse.

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

`X::Uploader::Validator`, which the uploaders validate their arguments with, is a private constant, as are `X::Uploader::Chunks`, `X::Uploader::Multipart`, and `X::Uploader::Utils`, which they upload and read files with, and the MIME type and media category tables of `X::Uploader::Media` are private constants: `MIME_TYPES`, `MIME_TYPE_MAP`, and the MIME type constants, such as `GIF_MIME_TYPE`, `MP4_MIME_TYPE`, and `SUBRIP_MIME_TYPE`. `PROCESSING_INFO_STATES` is gone, since `X::Uploader::UploadedMedia#processing?` tells whether media is still processing. The media category constants, such as `TWEET_IMAGE`, and `BYTES_PER_MB` remain public. Pass a file to `upload`, which raises `Errno::ENOENT` for a missing file and `ArgumentError` for an invalid category, or infer a type with `infer_media_type`.

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

`upload` and `chunked_upload` take media as a path or as an IO open on it, where 0.19 took a path alone. Media given as a `String` or a `Pathname` is read from the file it names, and media given as a `File` or a `Tempfile` through that IO, each a chunk at a time, so media of any size uploads without being held in memory; media given as any other IO, such as a `StringIO`, is read to its end and held. The media category of media that names no file is read from the bytes it begins with, so `client.upload_media(StringIO.new(png))` uploads an image, and media whose type neither its bytes nor the name of its file names, such as SubRip subtitles held in a `StringIO`, or a PDF, raises `X::InvalidMediaType` unless `media_category:` says what it is. The profile image and banner of `X::Uploader::Account` take a path or an IO too, where 0.19 took a path alone, and must begin with the signature of a GIF, a JPEG, or a PNG, whatever the file is named, or `X::InvalidMediaType` is raised, where 0.19 took a file by its extension `gif`, `jpg`, `jpeg`, or `png`, and sent a video named `.png`; a profile image larger than the 700 KB the API takes, or a banner larger than the 5 MB X takes, raises `X::InvalidMedia` before any request, and `update_profile_image_binary` and `update_profile_banner_binary` take the bytes. They are posted with the client they are given, with its credentials, to the API v1.1 at the host of its `base_url`, where 0.19 built a client of its own for `https://api.x.com/1.1/` from the OAuth 1.0a credentials.

A client has no `upload_media_binary`, since `upload_media` takes the media held in memory and infers its category. `X::Uploader::MediaUpload.upload_binary`, which 0.19 had as `X::MediaUploader.upload_binary`, remains for content whose category is known and which is to be uploaded in a single request without awaiting processing. It raises `ArgumentError` for the category of a video, or of subtitles, which the API takes in chunks alone, where 0.19 sent the request for the API to refuse:

```ruby
# 0.19
X::MediaUploader.upload_binary(client:, content:, media_category: "tweet_image")

# 1.0
client.upload_media(StringIO.new(content))                            # the category read from the signature
client.upload_media(StringIO.new(content), media_category: "tweet_image")
X::Uploader::MediaUpload.upload_binary(content, client:, media_category: "tweet_image")
```

`update_profile_image` returns nil, as `update_profile_banner` does, where 0.19 returned the user the API v1.1 answered with as a Hash: look the user up, as with `client.current_user!` of `x-objects`, to read the profile image it now has.

`upload`, `upload_binary`, `chunked_upload`, `await_processing`, and `await_processing!` return an `X::UploadedMedia` rather than a Hash. It is frozen, and reads as the Hash did with `[]`, `fetch`, which takes a default value and a block as `Hash#fetch` does, `dig`, and `key?`, so `media["size"]` and `media.dig("processing_info", "state")` work unchanged, and `to_h` returns the Hash for code that needs one, such as a comparison with a Hash or `media.merge(...)`. It also reads `id`, `media_key`, `bytesize`, the byte count that `media["size"]` holds, `expires_after_secs`, `state`, `processing?`, `failed?`, and `ready?`, and writes itself as its response with `as_json` and `to_json`. `media.id` reads the identifier as an Integer, while `media["id"]`, `media.to_h`, and the JSON of `as_json` and `to_json` hold the String the API gave, as the Hash of 0.19 did. Nothing else changes: `media_ids:` sends each identifier as a String, as it did. `upload` returns the processing status of media that X processes, such as a video or an animated GIF, rather than the response of the upload; both hold the media's identifier. The other uploaders return Hashes and Arrays whatever the `default_object_class` and `default_array_class` of the client, where `X::MediaUploader` parsed its responses with the client's classes.

`infer_media_type` is internal to x-uploader, where 0.19 documented it, since the rules it follows change as the types the API takes do; pass `media_type:` to `upload` or `chunked_upload` to send another type. An upload sends the type the media's bytes name, or else its extension, such as `video/quicktime` for `clip.mov` uploaded as `tweet_video`, where 0.19 sent `video/mp4` for every video, and `text/srt` for SubRip subtitles, where 0.19 sent `application/x-subrip`. Media of a type its category does not take, such as an MP4 video uploaded as `tweet_gif`, `dm_gif`, or `subtitles`, or a PNG uploaded as `tweet_video`, raises `X::InvalidMediaType` before any request, where 0.19 sent it as the first type of the category, an MP4 video as a GIF; pass the category of what it is, or `media_type:` to `chunked_upload` to send it as another type. `upload_binary` raises it too, for content whose signature names a type its category does not take, or names none for a GIF category. A file named as a type every file of which begins with a signature, such as `.png`, `.gif`, or `.ts`, that does not begin with it, such as TypeScript named `.ts`, raises `X::InvalidMediaType` too, and a file is categorized by its bytes before its name, so a PNG named `.gif` uploads as an image. An `.avi` or `.mkv` file that does not begin with the signature of a type the API documents, such as MP4 or WebM, media that begins with the header of Matroska and is not WebM, and a `.glb` or `.usdz` file raise `X::InvalidMediaType` before any request, whatever `media_category:` says, unless `media_type:` names the type to send, where 0.19 uploaded any of them as an MP4 video when told it was a video: the API documents no media type for AVI or Matroska, and no media category takes a 3D model.

`await_processing!` raises `X::MediaProcessingFailed` rather than `RuntimeError`, and `await_processing` raises `X::MediaProcessingTimeout` after ten minutes rather than waiting forever; pass `processing_timeout: Float::INFINITY` to wait for as long as processing takes, as 0.19 did, since a `processing_timeout` of nil raises `ArgumentError` before any request. It waits only while X reports the processing pending or in progress, so media whose processing is in a state X does not document, or in none, which 0.19 checked until it failed or succeeded, is returned after the check that reported it, neither `processing?` nor `ready?`, and `await_processing!` and `upload` raise `X::MediaProcessingFailed` for it, naming the state. A response of an upload that describes no media, or media whose identifier is nil or empty, raises `X::MissingMediaData`, and media given that holds no identifier, such as nil, `{}`, or an `X::UploadedMedia` built without one, raises `ArgumentError` before any request, as a mistake of the caller, where 0.19 raised `NoMethodError` or `KeyError`, or sent an empty `media_id`. `X::MissingMediaData`, `X::MediaProcessingFailed`, and `X::MediaProcessingTimeout` descend from `X::Uploader::Error`, an `X::Error`, so `rescue X::Uploader::Error` catches the failures of an upload alone. A file that does not exist raises `Errno::ENOENT` before any request, where 0.19 raised a `RuntimeError` that said "File not found", from the uploaders of media and of a profile image or banner alike, so rescue `Errno::ENOENT`, or `SystemCallError`, where code rescued `RuntimeError` for a missing file. Media that cannot be read, holds nothing, or is larger than the API takes raises `X::InvalidMedia` before any request, an `X::Uploader::Error` that `X::InvalidMediaType` descends from, so code that uploads what a user gives rescues it without rescuing the `ArgumentError` of its own mistakes, such as an invalid category.

A chunked upload that fails once it is initialized, at a chunk or at its finalize, raises `X::ChunkedUploadFailed`, an `X::Uploader::Error` whose `media` is the media the upload initialized, and whose `cause` is the error that failed it, where 0.19 raised the error of the request, such as `X::ServerError`, and lost the media, so rescue `X::ChunkedUploadFailed`, or read `error.cause`, where code rescued the error of the request. `update_profile_image_binary` and `update_profile_banner_binary`, which 0.19 named `upload_profile_image_binary` and `upload_profile_banner_binary`, raise `X::InvalidMedia` for empty content, and `X::InvalidMediaType` for content that is not a GIF, a JPEG, or a PNG, before any request, where 0.19 sent it for the API to refuse.

`chunk_size_mb:` is nil by default, which derives the chunk size from the size of the file, since the API numbers no more than 10,000 segments and the 1 MB chunks of 0.19 refused a file larger than 10,000 MiB after uploading about ten gigabytes of it. A file of ten gigabytes or less still uploads in 1 MB chunks. A chunk is 5 MB at most, the most X asks a segment to hold, and a file larger than the 16 GB of 1,073,741,824 bytes the API takes of an upload raises `X::InvalidMedia` before anything is uploaded, as a `chunk_size_mb:` above 5, which 0.19 sent for the server to refuse above 8 MB, or one that would need more than 10,000 segments, raises `ArgumentError`, and so does an `alt_text:` that is empty or longer than the 1,000 characters the API takes. An animated GIF larger than 5 MB uploads in chunks, which the API takes up to 15 MB of, where 0.19 sent it in a single request for X to refuse. An image larger than 5 MB, a GIF larger than 15 MB, and subtitles larger than 1 MB raise `X::InvalidMedia` before any request, where 0.19 uploaded them for X to refuse; a megabyte is 1,048,576 bytes, and the size of a video, which depends on the account, is left to X, up to the 16 GB it takes of any upload.

### Timeouts

`open_timeout` defaults to 10 seconds rather than the 60 of 0.19. Opening a connection is a TCP handshake and a TLS one, which a reachable host finishes in well under a second, so the shorter timeout gives up on a host that is not answering rather than hold a request for a minute. `read_timeout` and `write_timeout` are 60 seconds still, since an endpoint may be slow to answer. Pass `open_timeout: 60` for the old default, on a network where opening a connection is slow.

An `open_timeout`, `read_timeout`, or `write_timeout` is a finite number of seconds of at least 0, or nil for none, as in 0.19, and anything else, such as a String read from an environment variable, raises `ArgumentError` when the client is built, where 0.19 raised from inside `Net::HTTP` once a request waited.

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

A stream reconnects when it ends or drops, where 0.19 returned or raised, and raises once it has no reconnects left, `X::NetworkError` for a stream that ended as for one that dropped, so it no longer returns nil. Pass `max_reconnects: 0` to `streaming` to reconnect no stream, as 0.19 did, and rescue `X::NetworkError` where 0.19 returned once the stream ended. A stream reads with a `read_timeout` of its own, 30 seconds by default, where 0.19 read with the 60 of the client; pass `streaming(read_timeout: 60)` for the old one.

A stream authenticates as the app, which the stream endpoints take alone: a client that signs with OAuth 1.0a fetches the app's bearer token with its API key and secret, and a client that authenticates with OAuth 2.0 as a user streams with the app's `bearer_token`, or its `api_key` and `api_key_secret`, given beside the user's credentials, and raises `X::UnsupportedOperation` before it connects when it holds neither.

### Errors

A 4xx or 5xx status without an error class of its own raises `X::ClientError` or `X::ServerError` rather than `X::HTTPError`, and `X::NetworkError` wraps every network failure: `IOError`, which includes `EOFError`, `SystemCallError`, which includes every `Errno` error, `Timeout::Error`, `Net::ProtocolError`, `Net::HTTPBadResponse`, `Zlib::Error`, `OpenSSL::SSL::SSLError`, and `SocketError`. Rescuing `X::Error` still catches them all.

A successful response whose body is not JSON, such as the page of a proxy, raises `X::InvalidResponse`, an `X::HTTPError`, rather than returning nil. A successful response without a body still returns nil.

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

`X::OAuthAuthenticator::OAUTH_VERSION`, `OAUTH_SIGNATURE_METHOD`, and `OAUTH_SIGNATURE_ALGORITHM`, and `X::OAuth2Authenticator::REFRESH_GRANT_TYPE` are gone, since [simple_oauth](https://github.com/laserlemon/simple_oauth) signs requests and builds token refreshes now. `X::OAuth2Authenticator::TOKEN_HOST` and `TOKEN_PATH` are now one constant, `TOKEN_URL`. `X::MediaUploader::MAX_RETRIES` is gone, since a chunk is sent again up to the `max_retries` of the client, as an idempotent request is, and `X::AccountUploader::MIME_TYPE_MAP` is gone, since nothing read it. `X::AccountUploader::SUPPORTED_EXTENSIONS` is gone, since a profile image or banner is taken by its signature rather than its extension, and the endpoints `X::Uploader::Account` posts to, which 0.19 named in the public `X::AccountUploader::V1_BASE_URL`, are private constants, relative to the base URL of the client now. `X::HTTPError::JSON_CONTENT_TYPE_REGEXP` and `X::OAuth2Authenticator::EXPIRATION_BUFFER` are private constants, which can change within 1.x, and `X::Connection::DEFAULT_HOST` and `DEFAULT_PORT` are gone, since every request names its host. The gems no longer depend on `base64`, which `x` 0.19 did, so add it to your own Gemfile if you use it.
