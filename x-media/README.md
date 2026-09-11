# x-media

Media uploads for the [`x` gem](https://github.com/sferik/x-ruby), built on the HTTP client in [`x-core`](../x-core).

* `X::MediaUploader` uploads images, GIFs, videos, and subtitles. Large files are split into chunks that upload in parallel, with retries, and processing can be awaited.
* `X::AccountUploader` updates the authenticated user's profile image and banner through the v1.1 API.

Installing [`x`](https://rubygems.org/gems/x) installs this gem too.

## Installation

    bundle add x-media

## Usage

```ruby
require "x/media"

client = X::Client.new(**x_credentials)

media = X::MediaUploader.upload(client:, file_path: "cat.jpg", media_category: X::MediaUploader::TWEET_IMAGE)

video = X::MediaUploader.chunked_upload(client:, file_path: "cat.mp4", media_category: X::MediaUploader::TWEET_VIDEO)
X::MediaUploader.await_processing!(client:, media: video)

X::AccountUploader.update_profile_image(client:, file_path: "avatar.png")
```

The gem's version is `X::MediaUploader::VERSION`, because `X::Media` is the media resource in [`x-objects`](../x-objects).

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config. It uses the `x-core` in this repository and does not load `x-objects`:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
