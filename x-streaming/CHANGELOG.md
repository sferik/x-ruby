# Changelog

All notable changes to `x-streaming` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`x-streaming` is released in lockstep with the other gems of the [x-ruby](https://github.com/sferik/x-ruby) repository, at one version across `x-core`, `x-uploader`, `x-streaming`, `x-objects`, and `x`. This file holds the changes to the streams; [the changelog of the repository](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) holds the changes to every gem.

## [1.0.0] - 2026-10-02

The first release of `x-streaming`, which 1.0.0 split out of the `x` gem. The entries below are the changes since `x` 0.19, the last release before the split; see [UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) for the changes that code written for 0.19 needs. It requires Ruby 3.4 or later.

### Added
* Split the `x` gem into five gems released in lockstep, at one version
  * `x-core` (the HTTP client), `x-uploader` (uploads), `x-streaming` (streams and their rules), `x-objects` (resources).
  * `x` is a meta-gem that depends on all four and mixes their object, upload, and streaming methods into `X::Client`.
  * `x-core` declares `X::Error`, the base class of every error the gems raise.
  * Public classes sit directly under `X`; `X::Objects::Error`, `X::Uploader::Error`, and `X::Streaming::Error` catch one gem's.
  * Each gem depends on the others it needs with `>= 1.0.0, < 2`, so a later 1.x of one installs beside the others, and never an earlier one.
* Stream with `X::StreamingClient`, which `X::Client#streaming` builds from a client
  * It shares the client's credentials, base URL, parsing classes, and `on_response`, and keeps its own settings for life.
  * `X::Client#streaming` takes `read_timeout:`, `max_reconnects:`, and `on_reconnect:`; for other settings, stream from `client.with(...)`.
  * `stream` raises `ArgumentError` when given no block, before it opens the stream.
* Give a client `streaming` with `X::Streaming::API`, which `x` includes into `X::Client`
  * With `x-core` alone, call `X::Client.include(X::Streaming::API)`, or build one with `X::StreamingClient.new(client)`.
  * A streaming client opens each stream with `X::Client#get_stream` of `x-core`.
* Stop the streams of a streaming client from any thread, or the trap of a signal, with `X::StreamingClient#stop`
  * Each stops the next time it waits on the API, at once for an idle stream or one waiting to reconnect.
  * A stopped streaming client stays stopped: a stream asked of it later returns nil at once, without a request.
  * Each stopped `stream` call returns nil, `stop` returns nil, and `stopped?` tells a stopped streaming client.
  * A block, `on_response`, or `on_reconnect` running at that moment runs to its end first.
  * `X::Client#streaming` builds a new streaming client each time, so keep the one you stop in a variable.
* Stop a stream from its block: `break` stops it and returns its value, and `throw` unwinds past it
  * An error raised by the block, by `on_response`, or by the `object_class` stops the stream and reaches the caller.
  * That includes `StopIteration`, and a `JSON::ParserError`, which is not taken for a line that is not JSON.
* Read and change the rules of the filtered stream with `rules`, `add_rules`, and `delete_rules` on `X::StreamingClient`
  * They authenticate as the app, as a stream does; `rules` takes `params:` and reads every page.
  * A rule to add is an `X::StreamRule`, a Hash of a `value` and `tag`, or a String; anything else raises `ArgumentError`.
  * A rule is deleted by its `id` (from an `X::StreamRule`, a Hash, an Integer, or an `X::MatchingRule`, and nothing else that answers `id`) or by its value.
  * So `delete_rules(post.matching_rules)` deletes the rules a post of `x-objects` matched.
  * `dry_run: true` has the API check the rules and change none; no rules send no request.
  * `add_rules` returns the rules added; `delete_rules` returns the number deleted.
* Yield each rule the API did not add or delete as an `X::Problem`, or raise `X::RulesRejected` without a block
  * `X::RulesRejected` holds the `problems`, and what the method would have returned as `added` or `deleted_count`.
* Add `X::StreamRule`, a frozen value of a rule's `value`, `tag`, and `id`, an Integer or nil for a rule to add
  * An `id` is an Integer that is not negative or a String of digits alone; anything else raises `ArgumentError`.
  * It compares and hashes by all three, reads as a Hash with `to_h`, and matches a pattern of them.
  * It writes itself with Marshal and YAML in a versioned format that every 1.x release reads back.
  * A format it does not read raises `X::UnsupportedMarshalFormat`.
* Stream with app-only authentication from a client that signs with OAuth 1.0a, since the stream endpoints refuse it
  * An OAuth 2.0 user client without app credentials streams, and reads and changes rules, as the user.
  * X refuses that with 403, which raises `X::Forbidden`, not `X::UnsupportedOperation` before connecting.
* Raise `X::StreamError`, an `X::Streaming::Error`, for a stream line that holds errors and no data
  * It holds the line's `problems`, reads the stream's `http_method` and `uri`, and names them in its message.
  * A line of `operational-disconnect`s alone reconnects, then raises once no reconnects are left; others raise at once.
  * `X::Problem#disconnect?` tells an `operational-disconnect` apart, and `on_response` is passed the line first.
* Reconnect a stream that ends, drops, or delivers a line that is not JSON, backing off as X recommends
  * It reconnects up to `max_reconnects` times in a row, unlimited by default; an object or keep-alive resets the count.
  * A line that is not JSON raises `X::InvalidResponse`, and an ended stream `X::NetworkError`, once no reconnects are left.
  * A rate limit backs off from a minute, doubling up to 320 seconds, or waits for a later reset.
  * A wait past `max_rate_limit_wait`, or the project's usage cap, raises `X::TooManyRequests` at once.
  * A server error, a 408, or a 409 backs off from 5 seconds, doubling up to 320 seconds, or waits longer for its `Retry-After`.
  * A `Retry-After` past `max_rate_limit_wait` raises the error at once.
  * What arrived of a line the stream ended within is dropped, neither parsed nor passed to `on_response`.
  * An error `on_response` raises for a failed response stops the stream and reaches the caller, as one for an object does.
  * A certificate that does not verify raises its `X::NetworkError` at once, since it would not verify on the next attempt.
* Report each reconnect of a stream to `on_reconnect:`, a callable passed the error and the seconds it waits
  * It is passed an error every time, never nil, and is called with those two arguments and no others throughout 1.x.
  * It can call `stop` to give up, as on a host that never resolves, and the stream returns nil.
  * An error it raises stops the stream and reaches the caller.
* Read a stream with the `read_timeout` of the streaming client, 30 seconds by default
* Raise `ArgumentError` from `X::Client#streaming` and `X::StreamingClient.new` for an invalid setting
  * `max_reconnects` must be an Integer of at least 0, or `Float::INFINITY`.
  * `read_timeout` must be a finite number of seconds of at least 25, or nil, since X sends a keep-alive every 20 seconds.
  * `stream` raises it too for an invalid `array_class`, `object_class`, or endpoint, before it opens the stream.
* Rescue the errors of `x-streaming`, `X::StreamError` and `X::RulesRejected`, with `X::Streaming::Error`, an `X::Error`
* Add `X::Streaming.gem_version`, which returns `X::Streaming::VERSION` as a `Gem::Version`
* Add `X::StreamingClient::DEFAULT_READ_TIMEOUT` and `X::StreamingClient::DEFAULT_MAX_RECONNECTS`
* Build `X::StreamError` and `X::RulesRejected` with public constructors, so code that rescues one can be tested
  * Each takes an optional message and `problems:`, beside `http_method:` and `uri:`, or `added:` and `deleted_count:`.
  * `raise X::StreamError, "dropped"` raises it as any other exception is raised.
* Raise `TypeError` from `Marshal.dump`, `YAML.dump`, `as_json`, and `to_json` of a streaming client
  * They would write the credentials of its client in the clear.
* Name the internals of `x-streaming` under `X::Streaming`, as private constants marked `@api private`
  * They are `StreamParser`, `ReconnectHandler`, `StreamRules`, `Validator`, `Stopper`, and `CallbackError`.
* Ship this changelog with `x-streaming`, which the `changelog_uri` of its gemspec names
* Ship a `.yardopts` with `x-streaming`, so its documentation on rubydoc.info leaves out the private API

### Changed
* Move `stream` from `X::Client` to `X::StreamingClient`, so that the client carries no streaming settings

[1.0.0]: https://github.com/sferik/x-ruby/releases/tag/v1.0.0
