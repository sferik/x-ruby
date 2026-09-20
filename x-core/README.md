# x-core

The HTTP layer of the [`x` gem](https://github.com/sferik/x-ruby): a small, dependency-light client for the [X API](https://developer.x.com) that returns parsed JSON.

It handles OAuth 1.0a, OAuth 2.0 with PKCE authorization and token refresh, and bearer tokens. It also handles redirects, proxies, timeouts, HTTP errors, and rate limits, and opens a GET whose body is read as it arrives, as a stream is. Its only dependency that is not a default gem is `simple_oauth`, which has no dependencies of its own; it also asks for net-http 0.8 or a later 0.x release, the default gem it sends its requests with, since the 0.6 that Ruby 3.4 ships cannot request a host named by an IPv6 literal. Media uploads live in [`x-uploader`](https://github.com/sferik/x-ruby/tree/main/x-uploader), and the streams of the API, read a post at a time and reconnected as X recommends, in [`x-streaming`](https://github.com/sferik/x-ruby/tree/main/x-streaming).

Most applications should install [`x`](https://rubygems.org/gems/x), which adds resource objects from [`x-objects`](https://github.com/sferik/x-ruby/tree/main/x-objects). Install `x-core` alone when you only want raw JSON.

## Installation

`x-core` requires Ruby 3.4 or later.

    bundle add x-core

## Usage

```ruby
require "x/core"

client = X::Client.new(bearer_token: "INSERT YOUR BEARER TOKEN HERE")

client.get("users/by/username/sferik")
# {"data"=>{"id"=>"7505382", "name"=>"Erik Berlin", "username"=>"sferik"}}

# A block reads the response of that one request: its status, headers, rate limits, and the resources it was
# billed for. The on_response of a client receives the same summary, for every request the client makes.
client.get("users/by/username/sferik") { |response| puts response.rate_limit&.remaining }

# A GET whose body is read as it arrives, as a stream is; x-streaming reads the streams of the API a post at a
# time with it, and reconnects them
client.get_stream("tweets/sample/stream") { |response| response.read_body { |chunk| print chunk } }
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
