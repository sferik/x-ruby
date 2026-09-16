[![x-core](https://github.com/sferik/x-ruby/actions/workflows/x-core.yml/badge.svg)](https://github.com/sferik/x-ruby/actions/workflows/x-core.yml)
[![x-uploader](https://github.com/sferik/x-ruby/actions/workflows/x-uploader.yml/badge.svg)](https://github.com/sferik/x-ruby/actions/workflows/x-uploader.yml)
[![x-objects](https://github.com/sferik/x-ruby/actions/workflows/x-objects.yml/badge.svg)](https://github.com/sferik/x-ruby/actions/workflows/x-objects.yml)
[![x](https://github.com/sferik/x-ruby/actions/workflows/x.yml/badge.svg)](https://github.com/sferik/x-ruby/actions/workflows/x.yml)
[![linter](https://github.com/sferik/x-ruby/actions/workflows/lint.yml/badge.svg)](https://github.com/sferik/x-ruby/actions/workflows/lint.yml)
[![maintainability](https://qlty.sh/gh/sferik/projects/x-ruby/maintainability.svg)](https://qlty.sh/gh/sferik/projects/x-ruby)
[![gem version](https://badge.fury.io/rb/x.svg)](https://rubygems.org/gems/x)

# A [Ruby](https://www.ruby-lang.org) interface to the [X API](https://developer.x.com)

## Follow

For updates and announcements, follow [this gem](https://x.com/gem) and [its creator](https://x.com/sferik) on X.

## Installation

Install the gem and add to the application's Gemfile:

    bundle add x

Or, if Bundler is not being used to manage dependencies:

    gem install x

## Architecture

The `x` gem is a thin meta-gem that combines three gems, which are released from this repository in lockstep:

| Gem | What it does | Runtime dependencies |
| --- | --- | --- |
| [`x-core`](x-core) | HTTP: authentication, requests, redirects, errors, rate limits, and streaming | `simple_oauth` |
| [`x-uploader`](x-uploader) | Uploads: images, GIFs, videos, and subtitles, in chunks when large, plus profile images and banners | `x-core` |
| [`x-objects`](x-objects) | Resources: `User`, `Post`, `List`, `DirectMessage`, `Space`, `Community`, `Media`, `Poll`, `Place`, and cursors | none |

`require "x"` loads all three, and mixes the object methods (`find_user`, `find_posts`, `search`, …) into `X::Client`. Any other request can return objects too, given a resource class as its `object_class`. If you only want raw JSON, depend on `x-core` alone. If you want the objects with your own HTTP client, depend on `x-objects` alone.

## Usage

> [!NOTE]
> First, obtain X credentials from <https://developer.x.com>.

```ruby
require "x"

x_credentials = {
  api_key:             "INSERT YOUR X API KEY HERE",
  api_key_secret:      "INSERT YOUR X API KEY SECRET HERE",
  access_token:        "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE",
}

# Initialize an X API client with your OAuth credentials
x_client = X::Client.new(**x_credentials)
```

### Objects

Every lookup requests all public fields and expansions, and returns immutable, thread-safe objects.

```ruby
user = x_client.find_user("sferik")    # a String is a username, an Integer is an ID
user.name                              # => "Erik Berlin"
user.followers_count                   # => 12345

post = x_client.find_post(1234567890)  # X::Post
post.text
post.created_at                        # => 2026-09-11 12:00:00 UTC
```

**Any endpoint.** For an endpoint without a method, pass a resource class as the `object_class` of a request. A response that holds one resource comes back as an object, and one that holds a list comes back as an array of the page you requested. The object holds only the fields you asked for, so `hydrate` fetches the rest.

```ruby
user = x_client.get("users/by/username/sferik", object_class: X::User)
user.followers_count                   # => nil, since the request didn't ask for it
user.hydrate.followers_count           # => 12345

x_client.get("users/#{user.id}/blocking", object_class: X::User) # => [#<X::User ...>, ...]
```

**Identity.** Resources with the same class and ID are equal (`==`, `eql?`, and `hash`), even when they come from different requests.

```ruby
post.author == x_client.find_user("sferik") # => true
[post.author, user].uniq.size          # => 1
```

**References.** Foreign keys have accessors that return objects. When the response included the referenced object, you get it with its fields. Otherwise, you get a stub that holds only the ID. `hydrate` fetches the full object once and memoizes it. `refresh` fetches it again.

```ruby
post.author                            # => #<X::User id="7505382" name="Erik Berlin" username="sferik" ...>
post.replied_to                        # => #<X::Post id="1234567889">, a stub
post.replied_to.hydrate.text           # one request
post.replied_to.hydrate.text           # memoized, no request
post.replied_to.refresh.text           # forces a new request
```

Within one response, every reference to the same resource is the same object, so hydrating a user from one post hydrates it for every post on that page.

**Pagination.** Collections are `X::Cursor` objects, which include `Enumerable`, remember the client that fetched them, and fetch pages lazily. Iterating requests the maximum page size, and pages are cached, so iterating twice costs no extra requests. `first(n)` and `take(n)` request a page of `n` instead, raised to the endpoint's minimum. `refresh` returns a cursor with an empty cache, and `ids` fetches nothing but identifiers.

```ruby
followers = user.followers             # max_results=1000 per page
followers.first(10)                    # one request for ten users
followers.count                        # fetches the remaining pages
followers.count                        # cached, no requests
followers.refresh.count                # starts over
followers.ids                          # => [14100886, ...], requesting only identifiers

x_client.search_posts("ruby -is:retweet").each { |post| puts post.text }
x_client.search_users("ruby").first(10)
x_client.search_communities("ruby").first(10)
x_client.current_user.home_timeline.first(10)
```

**Stubs.** `from_id` refers to a resource without a request, so a cursor can be built from an identifier alone. A reference the response did not expand is a stub too, and `stub?` tells the two apart.

```ruby
X::User.from_id(7505382, client: x_client).followers.ids
post.author.stub?                      # => false when the response included the author
X::User.hydrate_all(posts.map(&:author), client: x_client) # looks up the stubs in one batch
message.peer(x_client.current_user)    # the other participant of a direct message
```

**Costs.** The X API bills each resource a request returns, so the size of a page is the size of the bill. `first(n)` and `take(n)` read only what they return. Iterating a cursor, `count`, `to_a`, and `ids` read the whole collection, up to 1,000 users a page for followers and following. Other `Enumerable` methods, such as `find`, `include?`, and `lazy`, cannot know how much they will read, so they request the largest page too; pass `max_results:` to read less per request. `user.follows?(other)` takes one lookup when either user is the authenticated user, by reading the other's `connection_status`, and otherwise scans the users `user` follows. The API has no lookup for a list membership, so `list.member?(user)` scans: the members of a private list, and for a public list, whichever is smaller of its members and the lists the user is on, as `member_count` and `listed_count` tell.

```ruby
user.followers.first(10)               # ten users
user.followers.count                   # every follower
x_client.current_user.follows?(other)  # one lookup
other.follows?(x_client.current_user)  # one lookup
other.follows?(someone)                # scans everyone other follows
user.followers(max_results: 100).find { |follower| follower.verified? }
```

The API bills a resource once per UTC day, however often it is read, and bills only the resources a response returns as data, not the ones it includes, so expanding `post.author` costs nothing extra. Batch lookups ask for each ID once. Reads of the authenticated user's own data cost a fifth as much as other reads when that user owns the app: their posts, mentions, likes, bookmarks, followers, following, blocks, mutes, and lists. So `x_client.current_user.posts` is cheaper than searching for `from:sferik`. Actions take the authenticated user's ID from the prefix of an OAuth 1.0a access token, and so need no request to `users/me`.

Writes are billed by the request, and cost more than reads. Creating a post costs $0.015, or $0.20 when its text holds a URL, so a link costs more than ten times as much as the post around it. A like, repost, follow, or direct message costs $0.015, and undoing one costs $0.01. Prices change, so check the [pricing page](https://docs.x.com/x-api/getting-started/pricing) before a large run.

**Usage.** `usage` reports how many posts the app's project has read this billing cycle, against its monthly cap, and how many it read each day.

```ruby
usage = x_client.usage(days: 30)
usage.project_cap - usage.project_usage # the posts left to read this cycle
usage.daily                            # => {2026-09-14 00:00:00 UTC => 1234, ...}
usage.daily_by_app                     # the same, keyed by the ID of each of the project's apps
```

**Counting posts.** `count_posts` counts the posts from the last seven days that match a query, and `count_all_posts` counts every post, which needs full-archive access. Each costs one request per page of periods, whatever the count. The counts and usage endpoints refuse OAuth 1.0a, so a client that signs with it makes those requests through `app_only`, a copy of itself that authenticates as the app. The client fetches the app's bearer token the first time and reuses it.

```ruby
x_client.count_posts("ruby")           # => 12345
x_client.post_counts("ruby", granularity: "hour") # => {2026-09-14 12:00:00 UTC => 42, ...}
X::Post.count_all("ruby", client: x_client, start_time: "2020-01-01T00:00:00Z")
```

**Missing resources.** A finder returns nil when the resource does not exist, and its bang form raises `X::ResourceNotFound`, an `X::Error`.

```ruby
x_client.find_user("nobody")           # => nil
x_client.find_user!("nobody")          # raises X::ResourceNotFound
post.permalink                         # => "https://x.com/sferik/status/1234567890"
post.expanded_text                     # the text with every t.co link replaced by the URL it stands for
```

**Partial errors.** A response can succeed and still report problems, such as a pinned post that was deleted or one ID of a batch that does not exist. `problems` returns them as `X::Problem` objects on any resource, and on each page of a cursor. A finder yields each one to a block, and `X::ResourceNotFound#problems` holds the ones that explain a missing resource.

```ruby
user = x_client.find_user("sferik")
user.problems                          # => [#<X::Problem Not Found Error: Could not find post with pinned_tweet_id: [1234567890].>]
x_client.find_users(ids) { |problem| warn problem.detail if problem.not_found? }
x_client.find_user!("nobody")          # raises X::ResourceNotFound: Could not find X::User nobody: Could not find user with username: [nobody].
```

**Parallel requests.** Batch lookups split the IDs into groups of 100, the API maximum, and request the groups in parallel. Paginated endpoints return a token for the next page with each page, so their pages must be fetched in order. `prefetch` fetches the next page in a background thread while you process the current one. It is opt-in because it spends one extra request when you stop iterating early.

```ruby
x_client.find_users(follower_ids)                       # parallel batches of 100, in the order asked for
user.followers.prefetch.each { |follower| process(follower) }
```

**Actions.** Actions are taken as the authenticated user.

```ruby
me = x_client.current_user             # fetched once per client
me.follow(user)
me.block(user)
me.like(post)
me.repost(post)
me.bookmark(post)

x_client.like(post)                    # the same, via the client
post = x_client.create_post("Hello, World! (from @gem)")
reply = x_client.create_post("Hello back!", reply_to: post, media_ids: [media["id"]])
quote = x_client.create_post("Worth reading", quote: post)
x_client.hide_reply(reply)              # as the author of the post it replies to
post.delete

list = x_client.create_list("Rubyists", private: true)
list.add_member(user)
me.pin_list(list)                      # also unpin_list, follow_list, and unfollow_list
list.delete

message = x_client.create_dm(user, "Hello!") # create_direct_message, shortened
x_client.dms_with(user).first(10)          # the conversation with a user
```

### Raw JSON

`X::Client` still speaks raw JSON, for endpoints without objects or when you want full control.

```ruby
# Get data about yourself
x_client.get("users/me")
# {"data"=>{"id"=>"7505382", "name"=>"Erik Berlin", "username"=>"sferik"}}

# Query parameters drop nil values and join arrays with commas
x_client.get("users", params: {ids: [7505382, 12], "user.fields": %w[id username]})

# Post, with a Hash encoded as JSON
post = x_client.post("tweets", {text: "Hello, World! (from @gem)"})
# {"data"=>{"edit_history_post_ids"=>["1234567890123456789"], "id"=>"1234567890123456789", "text"=>"Hello, World! (from @gem)"}}

# Delete the post
x_client.delete("tweets/#{post["data"]["id"]}")
# {"data"=>{"deleted"=>true}}

# Derive an API v1.1 client
v1_client = x_client.copy(base_url: "https://api.x.com/1.1/")

# Post a form
v1_client.post("account/settings.json", form: {lang: "en"})

# Authenticate as the app, with a bearer token fetched once with the API key and secret
x_client.app_only.get("tweets/search/stream/rules")

# Authenticate with OAuth 2.0, refreshing the access token when it expires or the API rejects it,
# and store the tokens of each refresh, since X accepts a refresh token only once
oauth2_client = X::Client.new(client_id: "ID", client_secret: "SECRET", access_token: "TOKEN", refresh_token: "REFRESH",
  expires_at: Time.now + 7200, on_token_refresh: ->(auth) { store(auth.access_token, auth.refresh_token, auth.expires_at) })

# Ask a user to authorize the app with OAuth 2.0 and PKCE, keeping the state and code verifier until X redirects back
authorization = X::OAuth2Authorization.new(client_id: "ID", redirect_uri: "https://example.com/callback",
  scopes: %w[tweet.read tweet.write users.read offline.access])
session[:oauth2] = {state: authorization.state, code_verifier: authorization.code_verifier}
redirect_to authorization.url

# Then, where X redirects back, exchange the code for a client that acts for the user
authorization = X::OAuth2Authorization.new(client_id: "ID", redirect_uri: "https://example.com/callback", **session[:oauth2])
user_client = authorization.client(request.url, on_token_refresh: ->(auth) { store(auth.refresh_token) })

# Define a custom response object
Language = Struct.new(:code, :name, :local_name, :status, :debug)

# Parse a response with custom array and object classes
languages = v1_client.get("help/languages.json", object_class: Language, array_class: Set)
# #<Set: {#<struct Language code="ur", name="Urdu", local_name="اردو", status="beta", debug=false>, …

# Access data with dots instead of brackets
languages.first.local_name

# Initialize an Ads API client
ads_client = X::Client.new(base_url: "https://ads-api.x.com/12/", **x_credentials)

# Get your ad accounts
ads_client.get("accounts")
```

### Media

```ruby
# The media category is inferred from the file: an image, an animated GIF, a video, or subtitles.
# A GIF with a single frame is uploaded as an image, since X processes only animated GIFs as GIFs.
media = X::Uploader::Media.upload("cat.jpg", client: x_client, alt_text: "A cat asleep on a keyboard")
x_client.create_post("Look at this cat", media_ids: [media])

# A video is uploaded in chunks, four at a time unless concurrency says otherwise, and upload waits until a video or
# an animated GIF has been processed, for up to ten minutes unless processing_timeout says otherwise
video = X::Uploader::Media.upload("cat.mp4", client: x_client)
subtitles = X::Uploader::Media.upload("cat.srt", client: x_client)
X::Uploader::Metadata.add_subtitles(video, subtitles, "EN", client: x_client, display_name: "English")
x_client.create_post("Look at this cat move", media_ids: [video])
```

### Streaming

A stream holds a connection open instead of answering a request, so `X::StreamingClient` handles one, and `streaming` builds it from a client. It shares the client's credentials, base URL, parsing classes, and `on_response` hook, and keeps the settings a long-lived connection needs: `read_timeout`, 20 seconds by default, and `max_reconnects`.

The stream endpoints take app-only authentication, so a client that signs with OAuth 1.0a streams with the bearer token that `app_only` holds. The endpoints that manage stream rules take it too, so send those through `app_only`.

X holds a stream open indefinitely, but drops it for deploys, network trouble, and slow readers. A stream that ends or drops reconnects at once, then waits a quarter second longer each attempt, up to 16 seconds. A server error or a refused connection waits 5 seconds, doubling each attempt, up to 320 seconds. A rate limit waits until it resets, or from a minute, doubling each attempt. Delivering a post starts the count over. A stream reconnects without limit by default; set `max_reconnects` to give up after that many attempts in a row. An error raised by the block always stops the stream.

X sends a newline every 20 seconds to keep an idle stream alive, so a stream reads with a 20-second timeout of its own. A connection that goes quiet is dropped and reconnected rather than held open until the 60-second `read_timeout` of an ordinary request.

```ruby
# Set up rules for filtered stream
x_client.app_only.post("tweets/search/stream/rules", {add: [{value: "ruby"}]})

# Stream matching posts in real time, until interrupted
x_client.streaming.stream("tweets/search/stream") do |post|
  puts post["data"]["text"]
end

# Give up after five reconnects in a row, and notice a quiet connection sooner
streaming_client = x_client.streaming(max_reconnects: 5, read_timeout: 10)
```

### Responses

A client calls its `on_response` after every request with an `X::Response`, which counts the resources the response returned and reads its rate limits. The API returns rate limit headers with nearly every response, and some writes add limits on the requests of a day. The API bills each post a stream delivers, so a stream calls `on_response` for each one, with that post as the body.

```ruby
x_client.on_response = lambda do |response|
  puts "#{response.http_method} #{response.uri.path}: #{response.resource_counts}" # {"data" => 100, "users" => 42}
  limit = response.rate_limit
  puts "#{limit.remaining} of #{limit.limit} left, resetting in #{limit.reset_in} seconds" if limit
end
```

**Rate limits.** A request the API refuses for a rate limit raises `X::TooManyRequests`, whose `retry_after` is the number of seconds until the limit resets. A client can instead wait and retry, up to `max_rate_limit_retries` times, which is 0 by default. It waits only as long as `max_rate_limit_wait`, which is 900 seconds by default, the length of a 15-minute window. A request whose limit resets later, such as a limit on the requests of a day, raises at once. A refusal that does not say when its limit resets waits a minute before the first retry, doubling the wait for each retry after, as X recommends. Each retry signs the request afresh and passes its response to `on_response`. The API refuses a rate-limited request without acting on it, so retrying a write does not repeat it. A stream is the exception to the default: `X::StreamingClient` reconnects after a rate limit however `max_rate_limit_retries` is set.

```ruby
x_client = X::Client.new(**x_credentials, max_rate_limit_retries: 3, max_rate_limit_wait: 60)
x_client.max_rate_limit_retries = 0    # raise X::TooManyRequests at once again
```

See other common usage [examples](https://github.com/sferik/x-ruby/tree/main/examples).

## History and Philosophy

This library is a rewrite of the [Twitter Ruby library](https://github.com/sferik/twitter). Over 16 years of development, that library ballooned to over 3,000 lines of code (plus 7,500 lines of tests), not counting dependencies. The HTTP layer of this library, `x-core`, is about 1,000 lines of code (plus 2,000 test lines) and only depends on the `simple_oauth` gem, which has no dependencies of its own. That doesn’t mean new features won’t be added over time, but the benefits of more code must be weighed against the benefits of less:

* Less code is easier to maintain.
* Less code means fewer bugs.
* Less code runs faster.

In the immortal words of [Ezra Zygmuntowicz](https://github.com/ezmobius) and his [Merb](https://github.com/merb) project (may they both rest in peace):

> No code is faster than no code.

The tests for the previous version of this library executed in about 2 seconds. That sounds pretty fast until you see that the tests for this library run in a fraction of a second. This means you can automatically run the tests any time you write a file and receive immediate feedback. For such workflows, 2 seconds feels painfully slow.

This code is not littered with comments that are intended to generate documentation. Rather, this code is intended to be simple enough to serve as its own documentation. If you want to understand how something works, don’t read the documentation—it might be wrong—read the code. The code is always right.

## Features

If this entire library is implemented in under 3,000 lines of code, why should you use it at all vs. writing your own library that suits your needs? If you feel inspired to do that, don’t let me discourage you, but this library has some advanced features that may not be initially apparent, including:

* OAuth 1.0 Revision A
* OAuth 2.0
* App-only authentication
* Thread safety
* Persistent HTTP connections, reused across requests to the same host
* HTTP redirect following
* HTTP proxy support
* HTTP logging
* HTTP timeout configuration
* HTTP error handling
* Rate limit handling
* Retrying a request after waiting for its rate limit to reset
* Streaming (filtered stream, volume stream)
* Reconnecting a dropped stream
* Immutable resource objects with identity, references, and hydration
* Lazy, cached, Enumerable cursors that request the maximum page size
* Configurable base URLs for accessing different APIs/versions
* Query strings, JSON bodies, and form bodies built from Ruby values
* Uploading any file with one call, with alt text and subtitles
* Parallel uploading of large media files in chunks
* Parallel batch lookups
* Partial errors reported by a response that otherwise succeeded

## Sponsorship

The X gem is free to use, but with X API pricing tiers, it actually costs money to develop and maintain. By contributing to the project, you help us:

1. Maintain the library: Keeping it up-to-date and secure.
2. Add new features: Enhancements that make your life easier.
3. Provide support: Faster responses to issues and feature requests.

⭐️ Bonus: Sponsors will get priority support and influence over the project roadmap. We will also list your name or your company's logo on our GitHub page.

Building and maintaining an open-source project like this takes a considerable amount of time and effort. Your sponsorship can help sustain this project. Even a small monthly donation makes a huge difference!

[Click here to sponsor this project.](https://github.com/sponsors/sferik)

## Sponsors

Many thanks to our sponsors (listed in order of when they sponsored this project):

<a href="https://betterstack.com"><img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/better_stack.svg" alt="Better Stack" width="200" align="middle"></a>
<img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/spacer.png" width="20" align="middle">
<a href="https://sentry.io"><img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/sentry.svg" alt="Sentry" width="200" align="middle"></a>
<img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/spacer.png" width="20" align="middle">
<a href="https://ifttt.com"><img src="https://raw.githubusercontent.com/sferik/x-ruby/main/sponsor_logos/ifttt.svg" alt="IFTTT" width="200" align="middle"></a>

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
