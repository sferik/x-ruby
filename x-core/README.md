# x-core

The HTTP layer of the [`x` gem](https://github.com/sferik/x-ruby): a small, dependency-light client for the [X API](https://developer.x.com) that returns parsed JSON.

It handles OAuth 1.0a, OAuth 2.0 with PKCE authorization and token refresh, and bearer tokens. It also handles redirects, proxies, timeouts, HTTP errors, and rate limits, and opens a GET whose body is read as it arrives, as a stream is. Its only dependency that is not a default gem is `simple_oauth`, which has no dependencies of its own; it also asks for net-http 0.9.1 or a later 0.x release, the default gem it sends its requests with, since the 0.6 that Ruby 3.4 ships cannot request a host named by an IPv6 literal, and on Ruby 4.0 an earlier net-http does not retry a connection that times out opening. Media uploads live in [`x-uploads`](https://github.com/sferik/x-ruby/tree/main/x-uploads), and the streams of the API, read a post at a time and reconnected as X recommends, in [`x-streams`](https://github.com/sferik/x-ruby/tree/main/x-streams).

Most applications should install [`x`](https://rubygems.org/gems/x), which adds resource objects from [`x-resources`](https://github.com/sferik/x-ruby/tree/main/x-resources). Install `x-core` alone when you only want raw JSON.

## Installation

`x-core` requires Ruby 3.4 or later.

    bundle add x-core

## Usage

```ruby
require "x/core"

client = X::Client.new(bearer_token: "INSERT YOUR BEARER TOKEN HERE")

client.get("users/by/username/sferik")
# {"data"=>{"id"=>"7505382", "name"=>"Erik Berlin", "username"=>"sferik"}}

# A block reads the response of that one request: its status, headers, rate limits, and the resources it
# returned. The on_response of a client receives the same summary, for every request the client makes.
client.get("users/by/username/sferik") { |response| puts response.rate_limit&.remaining }

# A GET whose body is read as it arrives, as a stream is; x-streams reads the streams of the API a post at a
# time with it, and reconnects them. Its block is passed an X::StreamResponse, which reads the status, headers,
# and rate limits of the response, and its body a chunk at a time, in binary, or whole, as a UTF-8 String,
# without a block. A connection that drops, or a read that times out, raises X::NetworkError from read_body,
# inside the block, which may rescue it. The body is read once, inside the block: a second read, unless both
# read it whole, or a read once the block has returned, raises X::Error, which is not sent again
client.get_stream("tweets/sample/stream") { |response| response.read_body { |chunk| print chunk } }
```

`x-core` sends its requests with `Net::HTTP`, and keeps it out of what it promises: a block, a hook, an authenticator, and an error read the request and the response through objects of `x-core`'s own, `X::Response`, `X::StreamResponse`, the request an authenticator is passed, which the signatures type as `X::_AuthenticatorRequest`, and `X::HTTPError`, which every release of 1.x keeps. The `http_response` each of `X::Response`, `X::StreamResponse`, and `X::HTTPError` reads, and the `http_response:` an `X::Response` or an `X::HTTPError` is built with, are an escape hatch for what they do not read themselves: the object is the transport's, a `Net::HTTPResponse` today, and its class is not covered by the compatibility promise of 1.x.

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
