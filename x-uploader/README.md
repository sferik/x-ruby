# x-uploader

Media uploads for the [`x` gem](https://github.com/sferik/x-ruby), built on the HTTP client in [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

* `X::Uploader::Media` uploads images, GIFs, videos, and subtitles. Videos and subtitles are split into chunks that upload in parallel, with retries, and processing can be awaited.
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

Every method that takes a file takes its path as a `String` or a `Pathname`, and raises `Errno::ENOENT` for a file that does not exist. `await_processing` and `await_processing!` take the response of an upload or a media identifier, as `X::Uploader::Metadata` does.

`upload` infers the media category from the file. A GIF with a single frame is an image, because X processes only animated GIFs as GIFs, and `X::Uploader::Gif.animated?` tells the two apart. Videos are MP4, QuickTime, WebM, or MPEG-TS files and subtitles are SubRip (`.srt`) or WebVTT (`.vtt`) files, each uploaded in chunks as the type its extension names.

A chunked upload sends four chunks at once, `X::Uploader::Media::DEFAULT_CONCURRENCY`, unless `concurrency:` says otherwise. An exception raised in the thread that uploads, such as a timeout or an interrupt, stops every chunk, so no thread goes on uploading after the call has ended.

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
