# x-core

The HTTP layer of the [`x` gem](https://github.com/sferik/x-ruby): a small, dependency-light client for the [X API](https://developer.x.com) that returns parsed JSON.

It handles OAuth 1.0a, OAuth 2.0 with token refresh, and bearer tokens. It also handles redirects, proxies, timeouts, HTTP errors, rate limits, streaming, and chunked media uploads. It depends only on the `base64` gem.

Most applications should install [`x`](https://rubygems.org/gems/x), which adds resource objects from [`x-objects`](../x-objects). Install `x-core` alone when you only want raw JSON.

## Installation

    bundle add x-core

## Usage

```ruby
require "x/core"

client = X::Client.new(bearer_token: "INSERT YOUR BEARER TOKEN HERE")

client.get("users/by/username/sferik")
# {"data"=>{"id"=>"7505382", "name"=>"Erik Berlin", "username"=>"sferik"}}

client.stream("tweets/search/stream") { |post| puts post["data"]["text"] }
```

Media uploads are loaded on demand:

```ruby
require "x/core/media_uploader"

media = X::MediaUploader.upload(client:, file_path: "cat.jpg", media_category: X::MediaUploader::TWEET_IMAGE)
```

See the [`x` README](https://github.com/sferik/x-ruby#readme) for more examples.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config, and does not load the other gems in this repository:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
