# Changelog

All notable changes to `x-uploads` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`x-uploads` is released in lockstep with the other gems of the [x-ruby](https://github.com/sferik/x-ruby) repository, at one version across `x-core`, `x-uploads`, `x-streams`, `x-resources`, and `x`. This file holds the changes to the uploads; [the changelog of the repository](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) holds the changes to every gem.

## [1.0.0] - 2026-09-18

The first release of `x-uploads`, which 1.0.0 split out of the `x` gem. The entries below are the changes since `x` 0.19, the last release before the split; see [UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) for the changes that code written for 0.19 needs.

### Added
* Add `X::Uploads.gem_version`, which returns `VERSION` as a `Gem::Version`
* Split `x` into gems released in lockstep: `x-core`, `x-uploads`, `x-streams`, `x-resources`, and the `x` meta-gem
  * `x-core` is the HTTP client and declares `X::Error`, the base of every error the gems raise
  * `x-uploads` holds the media, profile image, and banner uploads
  * Public classes are named directly under `X`, whichever gem declares them
  * Rescue one gem's failures with `X::Uploads::Error`, `X::Resources::Error`, or `X::Streams::Error`
  * `x` depends on exactly its own version of the other four; `x-uploads`, `x-streams`, and `x-resources` each depend on `x-core` with `>= 1.0.0, < 2`
* Make `X::Uploads::MediaUpload.upload` handle any file: it infers the category, chunks videos, and awaits processing
  * The category is inferred from the bytes the media begins with, or else from its file extension
  * It takes the `media_type:`, `chunk_size:`, and `concurrency:` of a chunked upload; others raise `ArgumentError`
* Add upload methods to `X::Client` with `X::Uploads::API`, which `x` includes into `X::Client`
  * `upload_media`, `chunked_upload_media`, `await_media_processing`, and `await_media_processing!`
  * `add_alt_text`, `add_subtitles`, `update_profile_image`, and `update_profile_banner`
  * `chunked_upload_media` returns once the upload is finalized; wait with `await_media_processing(!)` when needed
  * Media that already says its processing ended, or an image's upload response, is awaited without a request
  * With `x-core` and `x-uploads` alone, include it yourself: `X::Client.include(X::Uploads::API)`
  * Passing `client:` to any of them raises `ArgumentError`
* Return an `X::UploadedMedia` in place of a Hash from every upload, wait, and metadata method
  * It reads `id` and `media_id` as Integers, and `media_key`, `bytesize`, `expires_after_secs`, `processing_info`, `state`, and `check_after_secs`
  * `processing?`, `failed?`, and `ready?` tell the state of its processing
  * It still reads as a Hash with `[]`, `fetch`, `dig`, `key?`, and `to_h`, so `media["id"]` keeps working
  * `add_alt_text` and `add_subtitles` return the media they describe, so a call chains to the upload
  * It is frozen, and raises `ArgumentError` unless built with an `"id"` of 1 to 19 digits, as an Integer or a String
  * Its Marshal and YAML formats are read by every 1.x release; an unknown one raises `X::UnsupportedFormat`
* Add alt text to uploaded media with the `alt_text:` of `upload`, or with `X::Uploads::Metadata.add_alt_text`
  * Alt text that is not a String of 1 to 1,000 characters convertible to UTF-8 raises `ArgumentError` before a request
  * `upload` validates `alt_text:` before uploading, so media is not lost to rejected alt text
  * An upload that cannot add its alt text raises `X::AltTextFailed`, which holds the uploaded `media`, for any `StandardError` but a `Timeout::Error` or an `X::TokenReportFailed`, which are raised as they are, as an interrupt is, but a timeout raised with its class, as by `Timeout.timeout(5, Timeout::Error)`, that lands in `save_tokens` is an `X::TokenReportFailed`, holding the tokens
* Attach uploaded subtitles to a video with `X::Uploads::Metadata.add_subtitles`
  * `media_category:` defaults to `"tweet_video"`, and takes `tweet_video` or `amplify_video` in any case
  * It also takes `TweetVideo` or `AmplifyVideo`, as the endpoint names them; any other category raises `ArgumentError`
  * A language code that is not two letters raises `ArgumentError` before a request; it is sent upcased
* Accept a media ID, a media key, an upload response, or anything that answers `media_key` as uploaded media
  * In `await_processing`, `await_processing!`, `add_alt_text`, and `add_subtitles`, and their client methods
  * Anything else, nil, media without an `"id"`, or an ID that is not 1 to 19 digits raises `ArgumentError`
* Share uploaded media with the `shared:` and `additional_owners:` of `upload`, `chunked_upload`, and `upload_media`
  * Shared media always uploads in chunks
  * An invalid `shared` or `additional_owners` raises `ArgumentError` before any request
* Upload a GIF with a single frame as an image, since X fails to process it as a GIF
* Take the media as the positional argument of the `X::Uploads::MediaUpload` and `X::Uploads::Account` methods
  * `client:` is a keyword, as in the object layer
* Name a media category with a Symbol, in any case, as in `media_category: :tweet_video`
* Add `X::Uploads::MediaUpload::DEFAULT_CONCURRENCY` (4) and `MAX_CONCURRENCY` (16), the chunks sent at once
* Add `X::Uploads::MediaUpload::DEFAULT_PROCESSING_TIMEOUT` (600 seconds) and the `AMPLIFY_VIDEO` category constant
* Add `X::Uploads::Error`, the base of the errors `x-uploads` raises itself
  * `X::AltTextFailed`, `X::ChunkedUploadFailed`, `X::InvalidMedia`, and `X::MediaProcessingCheckFailed` descend from it
  * So do `X::MediaProcessingFailed`, `X::MediaProcessingTimeout`, and `X::MissingMediaData`
  * `X::InvalidMedia` and its subclass `X::InvalidMediaType` mean media the API would refuse
  * Mistakes in arguments, such as a bad category, chunk size, or timeout, raise `ArgumentError` instead
  * Each error that holds media reads it as an `X::UploadedMedia` with `media`, and can be raised with a message alone
* Raise `X::MediaProcessingCheckFailed`, which holds the uploaded `media`, when an upload's processing check fails
* Raise `X::ChunkedUploadFailed`, which holds the initialized `media`, when a chunk or the finalize request fails
  * Also when the file is deleted, closed, or shrinks during the upload, or the finalize response holds no media
  * It and `X::MediaProcessingCheckFailed` are raised for any `StandardError`, as the `cause`, such as one `on_response` raises
  * A `Timeout::Error`, an `X::MediaProcessingTimeout`, or an interrupt is raised as it is, but a timeout raised with its class, as by `Timeout.timeout(5, Timeout::Error)`, that lands in `save_tokens` is an `X::TokenReportFailed`, holding the tokens
  * An `X::TokenReportFailed` is raised as it is too, from a chunk, the finalize, or a check, so `rescue X::TokenReportFailed` stores its `tokens`
* Ship this changelog with the gem, linked from the `changelog_uri` of its gemspec
* Ship a `.yardopts` with the gem, so its documentation on rubydoc.info leaves out the private API

### Changed
* Hold `VERSION` as a String rather than a `Gem::Version`; compare versions with `gem_version`
* Require Ruby 3.4 or later
* Accept an IO as well as a path in `upload`, `chunked_upload`, `upload_media`, and the profile image and banner methods
  * A `File` or `Tempfile` is read a chunk at a time, so media of any size is not held in memory
  * Any other IO, such as a `StringIO`, is read and held; one that can seek is read from its start and left where it was
  * A String that holds a NUL byte or a line break, as contents do, raises `ArgumentError`; pass a path or a `StringIO`
  * An IO that cannot be read, such as a closed `StringIO`, raises `X::InvalidMedia`
  * So does media the system refuses to read, such as a socket that is not connected, or a `File` closed while it is read, with its error as the `cause`
* Type media by the bytes it begins with before its file name
  * Media neither its bytes nor its name types, such as a HEIC photo, raises `X::InvalidMediaType`
  * Pass `media_category:` to upload such media; it was uploaded as an image
  * A file named as a signed type, such as `.png` or `.ts`, that lacks the signature raises `X::InvalidMediaType`
  * Media the category does not take, such as an MP4 with `media_category: "tweet_gif"`, raises `X::InvalidMediaType`
* Keep `infer_media_type` internal, as are `chunked_upload?`, `infer_media_category`, and `X::Uploads::Gif`
  * Pass `media_type:` to send a type other than the inferred one
* Send requests to `api.x.com` rather than `api.twitter.com` by default
* Post profile image and banner uploads with the client given, resolved against its base URL
  * They reach the client's host and reuse its connection, credentials, timeouts, and proxy
* Raise `X::InvalidMedia`, naming the path, for a file that does not exist, before any request
* Raise `X::MediaProcessingFailed` instead of `RuntimeError` for media that fails to process
  * `media` holds the status X reported; only the `failed` state is a failure
* Move the HTTP client into `x-core`, under `lib/x/core`, and the uploaders into `x-uploads`, under `lib/x/uploads`
* Rename `X::MediaUploader` to `X::Uploads::MediaUpload` and `X::AccountUploader` to `X::Uploads::Account`
  * `X::MediaUploadValidator` became `X::Uploads::Validator`, a private constant
* Make the internals of the uploaders private constants, so they can change within 1.x
  * The MIME type tables and constants of `X::Uploads::MediaUpload`, such as `MIME_TYPES` and `GIF_MIME_TYPE`
  * `BYTES_PER_MB`, `MAX_SIMPLE_UPLOAD_BYTES`, and the base URL and endpoints of `X::Uploads::Account`
  * The media category constants, such as `TWEET_IMAGE`, remain public
  * The signatures the gem ships declare its public interface alone
* Upload in chunks of 4 MB, `X::Uploads::MediaUpload::DEFAULT_CHUNK_SIZE`, rather than 1 MB, so a video takes a quarter of the requests
  * `chunk_size:` replaces `chunk_size_mb:`, takes bytes, and defaults to nil, which uploads in chunks of 4 MB
  * Upload a large video with a client whose `max_rate_limit_retries` is set, so a rate limit on a chunk is waited out
  * A file up to the 16 GB the API takes fits its 10,000 segments; a larger one raises `X::InvalidMedia`
* Upload an animated GIF larger than 5 MB in chunks, which the API takes up to 15 MB of
* Raise `X::MissingMediaData` instead of `KeyError`, or returning nil, for a response that holds no media or metadata
  * Media without an identifier raises it too, so every `X::UploadedMedia` an upload returns has one
  * Its `problems` hold the problems the response reported, and its message names the first one's detail

### Removed
* Remove `X::MediaUploader.upload_binary`; pass a `StringIO` to `X::Uploads::MediaUpload.upload` instead
* Remove `upload_profile_image_binary` and `upload_profile_banner_binary`; pass an IO, such as a `StringIO`, instead
* Remove `X::AccountUploader::MIME_TYPE_MAP`, which nothing read
* Remove the `boundary:` keyword of the upload methods; each upload generates its own
* Remove `require "x/media_uploader"` and `require "x/account_uploader"`
  * Require `x`, `x/uploads/media_upload`, or `x/uploads/account` instead
* Remove `PROCESSING_INFO_STATES`; use `X::UploadedMedia#processing?`
* Remove `MAX_RETRIES`; a chunk is sent again up to the client's `max_retries`

### Fixed
* Give up waiting for processing after `processing_timeout:` seconds, raising `X::MediaProcessingTimeout`
  * It defaults to 600 seconds; pass `nil` to wait as long as processing takes, as the client's timeouts do
  * `Float::INFINITY`, a negative number, or a non-number raises `ArgumentError` before any request
  * Applies to `upload`, `await_processing(!)`, and the client's `upload_media` and `await_media_processing(!)`
  * Waits at least a second between checks, and as long as X asks, instead of polling in a tight loop
  * Only `succeeded` and `failed` end the wait; any other state, even one X does not document, is still `processing?`
* Send a chunk or the finalize request again after a server or network error, up to the client's `max_retries`
  * It waits as `Retry-After` asks, up to a minute, or with a randomized backoff, instead of retrying at once
  * A chunk or the finalize request is sent again after a read timeout too, since neither is billed
* Upload at most `concurrency:` chunks at once, 4 by default, instead of starting a thread per chunk
  * Each chunk is read from the file as it is sent, rather than copied to a temporary file first
  * A chunk that fails stops the chunks not yet begun
  * `x-core` keeps 16 idle connections per host, so each of up to 16 senders keeps its connection between chunks
* Stop the threads of a chunked upload, and wait for them, when the call is interrupted or times out
  * A thread that cannot be started (`ThreadError`), or an interrupt while starting them, stops those already started
  * A thread storing the tokens of a refresh it made with `save_tokens` finishes storing them first
  * A thread reading a chunk finishes reading it first, so the file is closed rather than left open
* Validate the `chunk_size:` and `concurrency:` of `chunked_upload` before any request
  * `chunk_size` must be a positive Integer of at most 5,242,880 that fits within the API's 10,000 segments
  * `concurrency` must be an Integer from 1 to 16, `MAX_CONCURRENCY`
  * Anything else, such as a String read from the environment, raises `ArgumentError` instead of `NoMethodError`
* Validate profile images and banners before a request
  * An empty file, a profile image over 700 KB, or a banner over 5 MB raises `X::InvalidMedia`
  * A file whose bytes are not a GIF, JPEG, or PNG raises `X::InvalidMediaType`, whatever its name
  * A banner `width`, `height`, `offset_left`, or `offset_top` that is not a whole number raises `ArgumentError`
* Return nil from `update_profile_image` and `update_profile_banner`; look the user up to read the new image
* Raise `X::InvalidMedia` before any request for an empty file, or media that cannot be read
  * Such as a directory, an unreadable file, or a write-only IO, which raised `Errno::EISDIR`, `EACCES`, or `IOError`
* Raise `X::InvalidMedia` before any request for an image over 5 MB, a GIF over 15 MB, or subtitles over 1 MB
  * The size X takes of a video depends on the account, so it is left to X
* Raise `X::InvalidMedia` instead of `TypeError` for a `Pathname` of a file that does not exist
* Raise `X::MissingMediaData`, not `NoMethodError`, before any chunk when the initialize response holds no media
* Accept the `amplify_video` media category, uploading it in chunks and awaiting its processing
* Upload WebM, QuickTime, and MPEG-TS videos, WebVTT subtitles, and BMP, TIFF, and progressive JPEG images
  * Each is sent as its own type, where every video was sent as MP4 and all subtitles as SubRip
* Upload an `.m4v` file as an MP4 video, in chunks, rather than as an image
* Raise `X::InvalidMediaType` before any request for `.avi`, `.mkv`, `.glb`, and `.usdz` files
  * An `.avi` or `.mkv` file that begins with the signature of a type the API documents uploads as that type, as WebM does; a `.glb` or `.usdz` file is refused whatever it holds
* Upload subtitles in chunks as `text/srt`, the type the API names, instead of as `application/x-subrip` in one request
* Send the media category in lowercase, as the API documents it, whatever case it was given in
* Read the size of chunked media once, so a file that grows during the upload sends the `total_bytes` it declared
* Parse upload responses into Hashes and Arrays whatever the client's `default_object_class` and `default_array_class`
* Give a class that includes `X::Uploads::MediaUpload` or `X::Uploads::Account` their public methods alone
  * Helpers such as `init`, `append`, and `media_id` are not mixed in, so a method of one of those names cannot break it
* Declare `json` in `sig/manifest.yaml`, so `rbs collection` loads it for code that depends on `x-uploads`
* Link `changelog_uri` to the `main` branch rather than `master`

[1.0.0]: https://github.com/sferik/x-ruby/releases/tag/v1.0.0
