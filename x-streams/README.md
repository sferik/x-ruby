# x-streams

Streaming for the [`x` gem](https://github.com/sferik/x-ruby), built on the HTTP client in [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

* `X::StreamingClient` reads the sample and filtered streams of the X API, a post at a time, and reconnects a stream that drops, backing off as X recommends.
* It reads, adds, and deletes the rules of the filtered stream, each an `X::StreamRule`.

Its only dependency is `x-core`. Installing [`x`](https://rubygems.org/gems/x) installs this gem too, and `require "x"` gives every `X::Client` its `streaming` method.

## Installation

`x-streams` requires Ruby 3.4 or later.

    bundle add x-streams

## Usage

```ruby
require "x/core"
require "x/streams"

X::Client.include(X::Streams::API)

client = X::Client.new(bearer_token: "INSERT YOUR BEARER TOKEN HERE")

# A rule the app already has is not added again, and raises nothing, so the rules an app needs are added each time
# it boots; the rules returned are those added, and rules reads them all, each with its id and tag
client.streaming.add_rules([{value: "ruby -is:retweet", tag: "ruby"}, "crystal"])
client.streaming.rules # => [#<X::StreamRule id=1 value="ruby -is:retweet" tag="ruby">, ...]
client.streaming.stream("tweets/search/stream") { |post| puts post["data"]["text"] }

# A stream runs until its block, or stop, stops it: break to stop it and return a value, throw to unwind further out, or
# raise to stop it with an error the caller sees
first = client.streaming.stream("tweets/search/stream") { |post| break post }
```

Another thread, or the trap of a signal, stops every stream a streaming client runs with `stop`, and each stream it stops returns nil. A stream that a Fiber scheduler runs, as in an `Async` task, is stopped once its block next returns, at the next keep-alive, within 20 seconds, or within a second as it waits to reconnect. A stopped streaming client stays stopped, as `stopped?` tells: a stream asked of it later returns nil without a request. Keep the streaming client you stop in a variable, since each call to `client.streaming` builds a new one.

`X::Client.include(X::Streams::API)` gives a client `streaming`, as `x` does, and a type checker needs the include declared too, as the `sig/x.rbs` of `x` declares it, with `class X::Client` and `include X::Streams::API` in a signature of your own; without the include, build a streaming client of a client with `X::StreamingClient.new(client)`, which takes the same `read_timeout:`, `max_reconnects:`, and `on_reconnect:`, a callable passed the error and the wait of each reconnect.

A streaming client opens each stream with `X::Client#get_stream` of `x-core`, the public method of a client that sends a GET whose body is read as it arrives, from an app-only copy of the client whose `read_timeout` is the stream's (a client that authenticates with OAuth 2.0 as a user and holds no credentials of the app streams as the user, which X refuses with `X::Forbidden`), so a stream carries the credentials, headers, and proxy of the client as any request does. It reads each line of the stream into the object it delivers, passes each to the client's `on_response` as an `X::Response`, and reconnects after a dropped connection, a server error, a rate limit, or an `operational-disconnect`, as the [`x` README](https://github.com/sferik/x-ruby#streaming) describes.

A stream reconnects at once the first time it drops, then waits longer before each reconnect in a row, up to `max_reconnects` of them. An object or keep-alive read from a connection that has been open for a minute starts the waits and the count over; one read from a younger connection starts neither over, so a stream whose connections each deliver something and drop backs off, and runs out of reconnects, rather than reconnect at once without end.

`X::StreamError`, which a line of a stream that holds errors and no data raises, and `X::RulesRejected`, which `add_rules` and `delete_rules` raise for the rules the API rejected when no block takes them (a rule the app already has is not one of them: `add_rules` raises nothing for it, yields its `DuplicateRule` to a block, and returns the rules it added alone, so read a rule the app already had, with its `id` and `tag`, with `rules`), descend from `X::Streams::Error`, which descends from `X::Error`, so `rescue X::Streams::Error` catches the errors x-streams raises of its own, and `rescue X::Error` every failure of a stream.

With `x-resources` loaded as well, a stream builds each post as an `X::Post` given `object_class: X::Post`, whose `matching_rules` are the rules of the filtered stream it matched.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config. It uses the `x-core` in this repository and does not load `x-resources` or `x-uploads`:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
