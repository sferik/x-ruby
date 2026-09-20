# x-uploader

Media uploads for the [`x` gem](https://github.com/sferik/x-ruby), built on the HTTP client in [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

* `X::Uploader::Media` uploads images, GIFs, videos, and subtitles. Videos, subtitles, and a GIF larger than a single request takes are split into chunks that upload in parallel, with retries, and processing can be awaited.
* `X::Uploader::Account` updates the authenticated user's profile image and banner through the v1.1 API.

Installing [`x`](https://rubygems.org/gems/x) installs this gem too.

## Installation

    bundle add x-uploader

## Usage

```ruby
require "x/uploader"

client = X::Client.new(**x_credentials)

media = X::Uploader::Media.upload("cat.jpg", client:, alt_text: "A cat asleep on a keyboard")

video = X::Uploader::Media.chunked_upload("cat.mp4", client:)
X::Uploader::Media.await_processing!(video, client:)

subtitles = X::Uploader::Media.upload("cat.srt", client:)
X::Uploader::Metadata.add_subtitles(video, subtitles, "EN", client:, display_name: "English")

X::Uploader::Account.update_profile_image("avatar.png", client:)
```

An upload returns an `X::Uploader::UploadedMedia`, a frozen object that holds the response, or the processing status of media that X processes. It reads `id`, as an Integer, `media_key`, `bytesize`, `expires_at`, and `state`, tells `processing?`, `failed?`, and `ready?`, and still reads as the Hash an upload used to return, with `[]`, `fetch`, `dig`, `key?`, `to_h`, and `to_json`. The uploaders take it wherever they take media, as `create_post` of `x-objects` does, and `find_media(media.media_key)` of `x-objects` looks up the `X::Media` it became, with its URL and variants.

```ruby
media.id          # => 1880028106020515840
media["id"]       # => "1880028106020515840"
media.ready?      # => true once X has processed it, or at once for an image
media.expires_at  # => 2026-09-19 12:00:00 UTC
```

`X::Uploader::API` holds the uploads a client is most often asked for, as methods that call the uploaders with the client. The `x` gem includes it into `X::Client`. With `x-core` and `x-uploader` alone, include it yourself:

```ruby
X::Client.include(X::Uploader::API)

media = client.upload_media("cat.jpg", alt_text: "A cat asleep on a keyboard")
client.upload_media_binary(File.binread("cat.png"), media_category: "tweet_image")
client.await_media_processing(video)      # returns the status, failed or not
client.await_media_processing!(video)     # raises X::Uploader::MediaProcessingFailed if processing failed
client.add_alt_text(media, "A cat asleep on a keyboard")
client.add_subtitles(video, subtitles, "EN", display_name: "English")
client.update_profile_image("avatar.png")
client.update_profile_banner("banner.png", width: 1500, height: 500)
```

Every method that takes a file takes its path as a `String` or a `Pathname`, and raises `Errno::ENOENT` for a file that does not exist. A media category is read in any case, as a `String` or a `Symbol`, and alt text of more than the 1,000 characters the API takes, or of none, raises `ArgumentError` before anything is uploaded. `await_processing` and `await_processing!` take the response of an upload or a media identifier, as `X::Uploader::Metadata` does.

`upload` infers the media category from the file. A GIF with a single frame is an image, because X processes only animated GIFs as GIFs, and `X::Uploader::Gif.animated?` tells the two apart. Videos are MP4, QuickTime, WebM, or MPEG-TS files and subtitles are SubRip (`.srt`) or WebVTT (`.vtt`) files, each uploaded in chunks as the type its extension names. An `.m4v` file is MP4, and an `.avi` or `.mkv` file, which the API documents no type for, is a video too, uploaded in chunks as MP4, for X to decide whether it can process it.

`X::Uploader::InvalidMediaType`, `X::Uploader::MediaProcessingFailed`, and `X::Uploader::MediaProcessingTimeout` descend from `X::Uploader::Error`, which descends from `X::Error`, so `rescue X::Uploader::Error` catches the failure of an upload alone.

A chunked upload sends four chunks at once, `X::Uploader::Media::DEFAULT_CONCURRENCY`, unless `concurrency:` says otherwise. It uploads in chunks of a megabyte, or of as much more as it takes to upload the file in the 1,000 segments the API numbers, unless `chunk_size_mb:` says otherwise; a chunk size that would need more segments than that raises `ArgumentError` before anything is uploaded. An exception raised in the thread that uploads, such as a timeout or an interrupt, stops every chunk, so no thread goes on uploading after the call has ended.

The methods of `X::Uploader::Media`, `X::Uploader::Account`, and `X::Uploader::Metadata` can be called on the module, or on an instance of a class that includes it. Such a class gains the documented public methods alone, so its own methods, whatever their names, cannot change an upload.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config. It uses the `x-core` in this repository and does not load `x-objects`:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
