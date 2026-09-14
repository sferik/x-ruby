[![x-core](https://github.com/sferik/x-ruby/actions/workflows/x-core.yml/badge.svg)](https://github.com/sferik/x-ruby/actions/workflows/x-core.yml)
[![x-media](https://github.com/sferik/x-ruby/actions/workflows/x-media.yml/badge.svg)](https://github.com/sferik/x-ruby/actions/workflows/x-media.yml)
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
| [`x-media`](x-media) | Uploads: images, GIFs, videos, and subtitles, in chunks when large, plus profile images and banners | `x-core` |
| [`x-objects`](x-objects) | Resources: `User`, `Post`, `List`, `DirectMessage`, `Space`, `Media`, `Poll`, `Place`, and cursors | none |

`require "x"` loads `x-core` and `x-objects`, and mixes the object methods (`find_user`, `find_posts`, `search`, …) into `X::Client`. Any other request can return objects too, given a resource class as its `object_class`. Media uploads are loaded on demand with `require "x/media"`. If you only want raw JSON, depend on `x-core` alone. If you want the objects with your own HTTP client, depend on `x-objects` alone.

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

**Pagination.** Collections are `X::Cursor` objects, which include `Enumerable`, remember the client that fetched them, request the maximum page size, and fetch pages lazily. Pages are cached, so iterating twice costs no extra requests. `refresh` returns a cursor with an empty cache.

```ruby
followers = user.followers             # max_results=1000 per page
followers.first(10)                    # one request
followers.count                        # fetches the remaining pages
followers.count                        # cached, no requests
followers.refresh.count                # starts over

x_client.search("ruby -is:retweet").each { |post| puts post.text }
```

**Parallel requests.** Batch lookups split the IDs into groups of 100, the API maximum, and request the groups in parallel. Paginated endpoints return a token for the next page with each page, so their pages must be fetched in order. `prefetch` fetches the next page in a background thread while you process the current one. It is opt-in because it spends one extra request when you stop iterating early.

```ruby
x_client.find_users(follower_ids)                       # parallel batches of 100
user.followers.prefetch.each { |follower| process(follower) }
```

**Actions.** Actions are taken as the authenticated user.

```ruby
me = x_client.me
me.follow(user)
me.like(post)
me.repost(post)

x_client.like(post)                    # the same, via the client
post = x_client.create_post("Hello, World! (from @gem)")
post.delete
```

### Raw JSON

`X::Client` still speaks raw JSON, for endpoints without objects or when you want full control.

```ruby
# Get data about yourself
x_client.get("users/me")
# {"data"=>{"id"=>"7505382", "name"=>"Erik Berlin", "username"=>"sferik"}}

# Post
post = x_client.post("tweets", '{"text":"Hello, World! (from @gem)"}')
# {"data"=>{"edit_history_tweet_ids"=>["1234567890123456789"], "id"=>"1234567890123456789", "text"=>"Hello, World! (from @gem)"}}

# Delete the post
x_client.delete("tweets/#{post["data"]["id"]}")
# {"data"=>{"deleted"=>true}}

# Initialize an API v1.1 client
v1_client = X::Client.new(base_url: "https://api.twitter.com/1.1/", **x_credentials)

# Define a custom response object
Language = Struct.new(:code, :name, :local_name, :status, :debug)

# Parse a response with custom array and object classes
languages = v1_client.get("help/languages.json", object_class: Language, array_class: Set)
# #<Set: {#<struct Language code="ur", name="Urdu", local_name="اردو", status="beta", debug=false>, …

# Access data with dots instead of brackets
languages.first.local_name

# Initialize an Ads API client
ads_client = X::Client.new(base_url: "https://ads-api.twitter.com/12/", **x_credentials)

# Get your ad accounts
ads_client.get("accounts")
```

### Media

```ruby
require "x/media"

media = X::MediaUploader.upload(client: x_client, file_path: "cat.jpg", media_category: X::MediaUploader::TWEET_IMAGE)
x_client.create_post("Look at this cat", media: {media_ids: [media["id"]]})

# Large files are uploaded in parallel chunks
video = X::MediaUploader.chunked_upload(client: x_client, file_path: "cat.mp4", media_category: X::MediaUploader::TWEET_VIDEO)
X::MediaUploader.await_processing!(client: x_client, media: video)
```

### Streaming

```ruby
# Set up rules for filtered stream
x_client.post("tweets/search/stream/rules", '{"add": [{"value": "ruby"}]}')

# Stream matching posts in real time
x_client.stream("tweets/search/stream") do |post|
  puts post["data"]["text"]
end
```

See other common usage [examples](https://github.com/sferik/x-ruby/tree/main/examples).

## History and Philosophy

This library is a rewrite of the [Twitter Ruby library](https://github.com/sferik/twitter). Over 16 years of development, that library ballooned to over 3,000 lines of code (plus 7,500 lines of tests), not counting dependencies. The HTTP layer of this library, `x-core`, is less than 1,000 lines of code (plus 1,500 test lines), and the media uploads in `x-media` and the object layer in `x-objects` are each smaller still. Neither depends on anything outside the Ruby standard library, apart from the `simple_oauth` gem, which signs OAuth 1.0a requests and builds OAuth 2.0 ones, and which has no dependencies of its own. That doesn’t mean new features won’t be added over time, but the benefits of more code must be weighed against the benefits of less:

* Less code is easier to maintain.
* Less code means fewer bugs.
* Less code runs faster.

In the immortal words of [Ezra Zygmuntowicz](https://github.com/ezmobius) and his [Merb](https://github.com/merb) project (may they both rest in peace):

> No code is faster than no code.

The tests for the previous version of this library executed in about 2 seconds. That sounds pretty fast until you see that the tests for this library, including the tests that exercise its concurrency, run in less than half a second. This means you can automatically run the tests any time you write a file and receive immediate feedback. For such of workflows, 2 seconds feels painfully slow.

This code is not littered with comments that are intended to generate documentation. Rather, this code is intended to be simple enough to serve as its own documentation. If you want to understand how something works, don’t read the documentation—it might be wrong—read the code. The code is always right.

## Features

If this entire library is implemented in under 2,000 lines of code, why should you use it at all vs. writing your own library that suits your needs? If you feel inspired to do that, don’t let me discourage you, but this library has some advanced features that may not be apparent without diving into the code:

* OAuth 1.0 Revision A
* OAuth 2.0
* Thread safety
* HTTP redirect following
* HTTP proxy support
* HTTP logging
* HTTP timeout configuration
* HTTP error handling
* Rate limit handling
* Streaming (filtered stream, volume stream)
* Parsing JSON into custom response objects (e.g. OpenStruct)
* Configurable base URLs for accessing different APIs/versions
* Parallel uploading of large media files in chunks
* Immutable, thread-safe resource objects with identity, references, and hydration
* Lazy, cached, Enumerable cursors that request the maximum page size
* Parallel batch lookups

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

## Development

1. Clone the repo:

       git clone git@github.com:sferik/x-ruby.git

2. Enter the repo’s directory:

       cd x-ruby

3. Install dependencies via Bundler:

       bin/setup

   The root, `x-core`, `x-media`, and `x-objects` each have their own bundle, so `bundle update` in the root updates only the root bundle. To update them all:

       bin/update

4. Run the default Rake task to ensure all tests pass:

       bundle exec rake

   Each of `x-core`, `x-media`, and `x-objects` has its own `Gemfile`, `Rakefile`, `Steepfile`, signatures, test suite, and mutation config, and can be checked on its own:

       cd x-core && bundle exec rake

   From the root, `rake test`, `rake mutant`, `rake steep`, and `rake yardstick` run each gem's task inside that gem's directory, with that gem's bundle. Append a gem's name to run one, as in `rake test:x-core`, `rake steep:x-objects`, or `rake yardstick:x`.

   On GitHub, each gem's workflow runs only when that gem, or a gem it depends on, changes. The `x` workflow runs when the meta-gem or the code and signatures of any gem change, and the linter runs when any Ruby file changes.

5. Create a new branch for your feature or bug fix:

       git checkout -b my-new-branch

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sferik/x-ruby.

Pull requests will only be accepted if they meet all the following criteria:

1. Code must conform to [Standard Ruby](https://github.com/standardrb/standard#readme). This can be verified with:

       bundle exec rake standard

2. Code must conform to the [RuboCop rules](https://github.com/rubocop/rubocop#readme). This can be verified with:

       bundle exec rake rubocop

3. 100% line, branch, and method coverage in each gem. This can be verified with:

       bundle exec rake test

4. 100% mutation coverage in `x-core`, `x-media`, and `x-objects`. This can be verified with:

       bundle exec rake mutant

5. RBS type signatures (in each gem's `sig` directory). This can be verified with:

       bundle exec rake steep

6. 100% documentation coverage. This can be verified with:

       bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
