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
| [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core) | HTTP: authentication, requests, redirects, errors, rate limits, and streaming | `simple_oauth`, and `net-http`, a default gem |
| [`x-uploader`](https://github.com/sferik/x-ruby/tree/main/x-uploader) | Uploads: images, GIFs, videos, and subtitles, with videos and subtitles in chunks, plus profile images and banners | `x-core` |
| [`x-objects`](https://github.com/sferik/x-ruby/tree/main/x-objects) | Resources: `User`, `Post`, `List`, `DirectMessage`, `Space`, `Community`, `Media`, `Poll`, `Place`, and cursors | `x-core` |

`require "x"` loads all three, and mixes the object methods (`find_user`, `find_all_posts`, `search_posts`, …) and the upload methods (`upload_media`, `add_alt_text`, `update_profile_image`, …) into `X::Client`. Any other request can return objects too, given a resource class as its `object_class`. If you only want raw JSON, depend on `x-core` alone. If you want the objects with an HTTP client of your own, depend on `x-objects` alone: it makes no request itself, and takes `x-core` for the errors the X gems share. It asks the client you give it for `get`, `post`, `put`, and `delete`, each taking a path that already carries the query, an optional body for the two that send one, and `array_class:` and `object_class:`; [the client contract](https://github.com/sferik/x-ruby/tree/main/x-objects#the-client-contract) has the whole of it, and the `X::Objects::_Client` interface in [`sig/x-objects.rbs`](https://github.com/sferik/x-ruby/blob/main/x-objects/sig/x-objects.rbs) states it for a type checker.

Every class you write is named directly under `X`, whatever gem declares it: `X::Client` and `X::NotFound` from `x-core`, `X::User` and `X::MissingResource` from `x-objects`, `X::UploadedMedia` and `X::MediaProcessingFailed` from `x-uploader`. Each gem's module holds its own mixins and internals. `X::Objects::Error` and `X::Uploader::Error` are the two exceptions, since each is the name a `rescue` reaches for to catch the failures of that gem alone.

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
                                       # find_user_by_username and find_user_by_id say which you mean
user.name                              # => "Erik Berlin"
user.followers_count                   # => 12345

post = x_client.find_post(1234567890)  # X::Post
post.text                              # the full text, even of a post longer than 280 characters
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

**Pagination.** Collections are `X::Cursor` objects, which include `Enumerable`, remember the client that fetched them, and fetch pages lazily. Iterating requests the maximum page size, and pages are cached, so iterating twice costs no extra requests. `first(n)` and `take(n)` request a page of `n` instead, raised to the endpoint's minimum, and keep it, so an iteration after them pays for none of it again, and the first page of `each_page` holds what they read. `published_count` reads the number the API publishes for a collection, such as a user's `followers_count`, without paging through it, while `count` pages through the whole collection, as `Enumerable` does. A cursor has no `size`, so sizing an enumerator over it, such as `each_slice(2).size`, never pages it. `refresh` returns a cursor with an empty cache, and `ids` fetches nothing but identifiers.

```ruby
followers = user.followers             # max_results=1000 per page
followers.first(10)                    # one request for ten users
followers.empty?                       # one request for one user, as any? and none? make
followers.to_a                         # fetches the remaining pages
followers.to_a                         # cached, no requests
followers.refresh.to_a                 # starts over
followers.published_count              # => 12345, the user's followers_count, with no request
followers.ids                          # => [14100886, ...], requesting only identifiers

x_client.search_posts("ruby -is:retweet").each { |post| puts post.text }
x_client.search_users("ruby").first(10)
x_client.search_communities("ruby").first(10)
x_client.search_spaces("ruby", state: "live").first(10) # a client that signs with OAuth 1.0a searches as the app
x_client.current_user!.home_timeline.first(10)
```

**Stubs.** `from_id` refers to a resource without a request, so a cursor can be built from an identifier alone. A reference the response did not expand is a stub too, and `stub?` tells the two apart.

```ruby
X::User.from_id(7505382, client: x_client).followers.ids
post.author.stub?                      # => false when the response included the author
X::User.hydrate_all(posts.map(&:author), client: x_client) # looks up what is not hydrated, in one batch
message.peer(x_client.current_user!)   # the other participant of a direct message
```

**Costs.** The X API bills each resource a request returns, so the size of a page is the size of the bill. `first(n)` and `take(n)` read only what they return. Iterating a cursor, `to_a`, and `ids` read the whole collection, up to 1,000 users a page for followers and following. `count` reads the whole collection too, a request per page, billed for every resource, so counting a user with a million followers reads a million users in a thousand requests. `published_count` reads the number the API publishes instead, for a user's followers, followed users, and list memberships, and for a list's members and followers, which costs nothing when the user or list holds it and one lookup when it is a stub, and it returns nil for any other collection. The published number counts what the collection holds, which can differ from what reading it finds, since the API leaves out what the authenticated user cannot see. Other `Enumerable` methods, such as `find`, `include?`, and `lazy`, cannot know how much they will read, so they request the largest page too; pass `max_results:` to read less per request. `user.follows?(other)` takes one lookup when either user is the authenticated user, by reading the other's `connection_status`, and otherwise scans the users `user` follows. The API has no lookup for a list membership, so `list.member?(user)` scans: the members of a private list, and for a public list, whichever is smaller of its members and the lists the user is on, as `member_count` and `listed_count` tell.

```ruby
user.followers.first(10)               # ten users
user.followers.published_count         # the user's followers_count, reading no follower
user.followers.count                   # every follower, a request per 1,000
user.muting.published_count            # => nil, since the API publishes no number
x_client.current_user!.follows?(other) # one lookup
other.follows?(x_client.current_user!) # one lookup
other.follows?(someone)                # scans everyone other follows
user.followers(max_results: 100).find { |follower| follower.verified? }
```

The API bills a resource once per UTC day, however often it is read, and bills only the resources a response returns as data, not the ones it includes, so expanding `post.author` costs nothing extra. Batch lookups ask for each ID once. Reads of the authenticated user's own data cost a fifth as much as other reads when that user owns the app: their posts, mentions, likes, bookmarks, followers, following, blocks, mutes, and lists. So `x_client.current_user!.posts` is cheaper than searching for `from:sferik`. Actions take the authenticated user's ID from the prefix of an OAuth 1.0a access token, and so need no request to `users/me`.

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
x_client.count_posts_by_period("ruby", granularity: "hour") # => {2026-09-14 12:00:00 UTC => 42, ...}
X::Post.count_all("ruby", client: x_client, start_time: "2020-01-01T00:00:00Z")
```

**Missing resources.** A finder returns nil when the resource does not exist, and its bang form raises `X::MissingResource`, an `X::Error`. The API answers a lookup of a resource that is not there with 200 OK and no data, so this is not `X::NotFound`, which is the 404 of an endpoint that is not there.

```ruby
x_client.find_user("nobody")           # => nil
x_client.find_user!("nobody")          # raises X::MissingResource
x_client.find_user("not a username")   # raises ArgumentError, before any request
post.permalink                         # => "https://x.com/sferik/status/1234567890"
post.expanded_text                     # the text with every t.co link replaced by the URL it stands for
```

**Partial errors.** A response can succeed and still report problems, such as a pinned post that was deleted or one ID of a batch that does not exist. `problems` returns them as `X::Problem` objects on any resource, and on each page of a cursor. A finder yields each one to a block, and `X::MissingResource#problems` holds the ones that explain a missing resource.

```ruby
user = x_client.find_user("sferik")
user.problems                          # => [#<X::Problem Not Found Error: Could not find post with pinned_tweet_id: [1234567890].>]
x_client.find_all_users(ids) { |problem| warn problem.detail if problem.not_found? }
x_client.find_user!("nobody")          # raises X::MissingResource: Could not find X::User @nobody: Could not find user with username: [nobody].
```

**Parallel requests.** Batch lookups split the IDs into groups of 100, the API maximum, and request four groups at a time, as the chunks of an upload are sent four at a time. Pass a `concurrency` to request more or fewer at once: a lower number spends a rate limit more slowly. Paginated endpoints return a token for the next page with each page, so their pages must be fetched in order. `prefetch` fetches the next page in a background thread while you process the current one. It is opt-in because it spends one extra request when you stop iterating early.

```ruby
x_client.find_all_users(follower_ids)                       # parallel batches of 100, in the order asked for
x_client.find_all_users(follower_ids, concurrency: 1)       # one batch at a time
X::Post.find_all(ids, client: x_client, concurrency: 8)
user.followers.prefetch.each { |follower| process(follower) }
```

**Actions.** Actions are taken as the authenticated user. They take a resource or its identifier, an Integer or a String of digits, and raise `ArgumentError` for anything else, such as a username, so look a user up with `find_user` first.

```ruby
me = x_client.current_user!            # fetched once per client
me.follow(user)
me.block(user)
me.like(post)
me.repost(post)
me.bookmark(post)                      # bookmarks take OAuth 2.0 user context, which this client does not hold

x_client.like(post)                    # the same, via the client
post = x_client.create_post("Hello, World! (from @gem)")
reply = x_client.create_post("Hello back!", reply_to: post, media_ids: [media])
quote = x_client.create_post("Worth reading", quote: post)
photo = x_client.create_post(media_ids: [media]) # a post needs no text when it has media
x_client.hide_reply(reply)              # as the author of the post it replies to
post.delete

list = x_client.create_list("Rubyists", private: true)
list.update(description: "People who write Ruby") # also name and private
list.add_member(user)
me.pin_list(list)                      # also unpin_list, follow_list, and unfollow_list
list.delete

message = x_client.create_dm(user, "Hello!") # create_direct_message, shortened
x_client.dms_with(user).first(10)          # the conversation with a user

group = x_client.create_group_dm([user, other], "Hello, both of you!") # create_group_direct_message, shortened
x_client.create_dm_in(group, "Anyone free on Friday?") # to the conversation of a message, or its identifier
x_client.dms_in(group).first(10)           # the messages of a conversation, one-to-one or group
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
v1_client = x_client.with(base_url: "https://api.x.com/1.1/")

# Post a form
v1_client.post("account/settings.json", form: {lang: "en"})

# Authenticate as the app, with a bearer token fetched once with the API key and secret
x_client.app_only.get("tweets/search/stream/rules")

# Authenticate with OAuth 2.0, refreshing the access token when it expires or the API rejects it,
# and store the tokens of each refresh, since X accepts a refresh token only once; X::AuthorizationError
# means X refused to refresh, and a token endpoint that fails raises the X::ServerError the client retries
oauth2_client = X::Client.new(client_id: "ID", client_secret: "SECRET", access_token: "TOKEN", refresh_token: "REFRESH",
  expires_at: Time.now + 7200, on_token_refresh: ->(auth) { store(auth.access_token, auth.refresh_token, auth.expires_at) })

# Ask a user to authorize the app with OAuth 2.0 and PKCE, keeping the state and code verifier until X redirects back
authorization = X::OAuth2Authorization.new(client_id: "ID", redirect_uri: "https://example.com/callback",
  scopes: %w[tweet.read tweet.write users.read offline.access])
session[:state] = authorization.state
session[:code_verifier] = authorization.code_verifier
redirect_to authorization.url

# Then, where X redirects back, exchange the code for a client that acts for the user
authorization = X::OAuth2Authorization.new(client_id: "ID", redirect_uri: "https://example.com/callback",
  state: session[:state], code_verifier: session[:code_verifier])
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

# Keep a connection open for the next request for five seconds rather than 30, behind a proxy that closes idle
# connections sooner than X does
patient_client = X::Client.new(keep_alive_timeout: 5, **x_credentials)

# Send headers with every request, such as one that names your application. They are defaults: a header of the same
# name passed to a request, or to a stream, is sent in place of the client's, and each of the client's is sent in
# place of a default of the gem, such as its User-Agent.
named_client = X::Client.new(headers: {"User-Agent" => "my-app/1.0 (+https://example.com)"}, **x_credentials)
named_client.get("users/me", headers: {"X-Trace" => "abc"}) # sends both
traced_client = named_client.with(headers: {"X-Trace" => "abc"}) # a copy of a client, with other headers

# Send requests through a proxy. A client that is given none takes the proxy the environment names for the scheme of
# each request, in https_proxy or http_proxy, and reaches the hosts that no_proxy names directly.
proxied_client = X::Client.new(proxy_url: "http://user:password@proxy.example.com:8080", **x_credentials)

# Close the connections a client keeps open between requests; a later request opens one again
x_client.close
```

**A client never changes.** It keeps the credentials and settings it was built with for as long as it lives, so a request never runs against a setting another thread is halfway through changing. `with` derives a client that differs, and takes anything `X::Client.new` takes.

```ruby
v1_client = x_client.with(base_url: "https://api.x.com/1.1/")
rotated = x_client.with(access_token: "new_token", access_token_secret: "new_secret")
```

**A client keeps its credentials to its own origin.** An endpoint that names a whole URL is sent to that URL, and it carries the client's credentials only when it names the scheme, host, and port of the `base_url`, which the API version above does. An endpoint, or a stream, of any other origin is sent without the `Authorization` header the authenticator signs and without any `Authorization`, `Cookie`, or `Proxy-Authorization` header of the client or the request, as a redirect that leads off the origin is, so the credentials of the API never reach a host they were not meant for. A client built with another `base_url`, such as the Ads API client above, carries its credentials to that origin.

**A client keeps its credentials to itself.** It has no reader for a secret it holds, and `inspect` names its authenticator without revealing what it signs with, so nothing that reflects over a client reads a credential out of one. `with` carries them to a client derived from it, and the hook given to `on_token_refresh` is passed the authenticator, which holds the tokens of the refresh it reports.

```ruby
x_client.inspect                       # => #<X::Client base_url="https://api.x.com/2/" authenticator=#<X::OAuth1Authenticator>>
x_client.api_key                       # the API key, the client ID, and the expiration time are public
x_client.api_key_secret                # raises NoMethodError, as every secret a client holds does
```

### Media

```ruby
# The media category is inferred from the file: an image, an animated GIF, a video, or subtitles.
# A GIF with a single frame is uploaded as an image, since X processes only animated GIFs as GIFs.
media = x_client.upload_media("cat.jpg", alt_text: "A cat asleep on a keyboard")
media.id                               # => 1880028106020515840, where media["id"] is the String the API gave
media.expires_at                       # => 2026-09-19 12:00:00 UTC, after which it cannot be attached to a post
x_client.create_post("Look at this cat", media_ids: [media])
x_client.find_media(media).url         # the X::Media it became, looked up by media key
x_client.find_all_media(post.media)    # the media of a post, up to 100 keys per request

# A video, and an animated GIF larger than 5 MB, is uploaded in chunks, four at a time unless concurrency says
# otherwise, in chunks sized so that the upload fits the 1,000 segments the API numbers, and upload waits until a
# video or an animated GIF has been processed, for up to ten minutes unless processing_timeout says otherwise
video = x_client.upload_media("cat.mp4")
video.ready?                           # => true, since upload_media waited; state is "succeeded"
subtitles = x_client.upload_media("cat.srt")
x_client.add_subtitles(video, subtitles, "EN", display_name: "English")
x_client.create_post("Look at this cat move", media_ids: [video])

# Update the profile image and banner of the authenticated user. These two call the API v1.1, which the API v2 has
# no endpoint for, so they answer in its shape rather than with an X::User: update_profile_image returns the updated
# user as a Hash, keyed as v1.1 keys it, and update_profile_banner returns nil, since its endpoint sends no body.
user = x_client.update_profile_image("avatar.png")
user["screen_name"]                    # => "sferik", the v1.1 name for a username
x_client.update_profile_banner("banner.png") # => nil

# Media is a path, or an IO open on it. Media given as a String or a Pathname is read from the file it names, and
# media given as a File or a Tempfile through that IO, even once the Tempfile is unlinked, or from the file it names
# once it is closed, a chunk at a time, so media of any size uploads without being held in memory.
x_client.upload_media(Pathname("cat.jpg"))
File.open("cat.mp4", "rb") { |file| x_client.upload_media(file) }

# Media given as any other IO, such as a StringIO, is read to its end and held. Its category is read from the bytes
# it begins with, since it names no file: a GIF, PNG, JPEG, BMP, TIFF, WebP, glTF, MP4, QuickTime, WebM, or WebVTT
# file is recognized by its signature. Pass media_category for anything else, such as SubRip subtitles, which begin
# with nothing a text file could not.
x_client.upload_media(StringIO.new(png))
x_client.upload_media(StringIO.new(srt), media_category: "subtitles")
```

Each of these methods calls an uploader with the client: `upload_media`, `await_media_processing`, and `await_media_processing!`, which raises `X::MediaProcessingFailed` where the other returns the failed status, call `X::Uploader::MediaUpload`, `add_alt_text` and `add_subtitles` call `X::Uploader::Metadata`, and `update_profile_image` and `update_profile_banner` call `X::Uploader::Account`. The uploaders do more, such as `X::Uploader::MediaUpload.chunked_upload("cat.mp4", client: x_client, chunk_size_mb: 4)`, and take any client as `client:`.

What each returns: `upload_media`, `await_media_processing`, and `await_media_processing!` return an `X::UploadedMedia`, which reads as the Hash the API answered with as well as by its own methods; `add_alt_text` and `add_subtitles` return the `data` of the response as a Hash; `update_profile_image` returns the updated user as a Hash of the API v1.1, whose keys are the v1.1 ones, such as `screen_name` rather than `username`; and `update_profile_banner` returns nil, since its endpoint answers with no body. The two profile methods are the only ones in these gems that call the v1.1 API, which is why they alone answer outside the object layer.

### Streaming

A stream holds a connection open instead of answering a request, so `X::StreamingClient` handles one, and `streaming` builds it from a client. It shares the client's credentials, base URL, parsing classes, and `on_response` hook, and keeps the settings a long-lived connection needs: `read_timeout`, 30 seconds by default, and `max_reconnects`.

The stream endpoints take app-only authentication, so a client that authenticates as a user streams with the bearer token that `app_only` holds. A client that authenticates with OAuth 2.0 as a user and holds neither the app's bearer token nor its API key and secret has no credentials of the app, so `app_only` raises `X::UnsupportedOperation` for it, and so does a stream it opens, before it connects; give the client one of them, or stream with a client built from the app's bearer token, or its API key and secret, instead.

X holds a stream open indefinitely, but drops it for deploys, network trouble, and slow readers. A stream that ends, drops, or is refused a connection reconnects at once, then waits a quarter second longer each attempt, up to 16 seconds. A server error, a 409 Conflict, or a line that is not JSON waits 5 seconds, doubling each attempt, up to 320 seconds. A rate limit waits until it resets, or from a minute, doubling each attempt. Delivering a post starts the count over. A stream reconnects without limit by default; set `max_reconnects` to give up after that many attempts in a row.

**The rules of the filtered stream.** The filtered stream delivers the posts that match the rules of the app, which belong to the stream and are read and changed through a streaming client: `stream_rules` reads them, every page of them, `add_stream_rules` adds them, and `delete_stream_rules` deletes them, each authenticating as the app as a stream does. The API adds the rules it can, so `add_stream_rules` returns the ones it added and yields each one it did not, such as a rule the app already has, as the `X::Problem` the API reported. A rule to add is a `value` and the `tag` it is labelled with, or a String, which is the value of a rule with no tag. A rule is deleted by the identifier it was given, which a rule `stream_rules` returned, a Hash holding an `id`, or an Integer names, so what `stream_rules` returned deletes itself, or by the value it matches, which a Hash holding a `value` or a String names, so what `add_stream_rules` was given deletes what it added. No rules add or delete none, and send no request. `dry_run: true` has the API check the rules and change none of them.

**Stopping a stream.** A stream runs until its block stops it. `break` out of the block to stop the stream and return a value, or `throw` to unwind to a `catch` further out; neither reconnects. An error raised by the block stops the stream too, even one a dropped connection would have reconnected after, and reaches the caller unchanged, as does an error raised by `on_response` or by the class that builds each object. A `StopIteration` is an error like any other here, so a block that exhausts an `Enumerator` of its own hears about it rather than ending the stream in silence.

X sends a newline every 20 seconds to keep an idle stream alive, so a stream reads with a 30-second timeout of its own, which a keep-alive that arrives a little late does not trip. A connection that goes quiet is dropped and reconnected rather than held open until the 60-second `read_timeout` of an ordinary request.

```ruby
# Set up rules for the filtered stream
streaming = x_client.streaming
streaming.add_stream_rules([{value: "ruby -is:retweet", tag: "ruby"}, "crystal"])
streaming.stream_rules # => [{"id" => "1", "value" => "ruby -is:retweet", "tag" => "ruby"}, ...]

# Stream matching posts in real time, until interrupted
x_client.streaming.stream("tweets/search/stream") do |post|
  puts post["data"]["text"]
end

# Stop the stream from its block, which returns what break was given
first = x_client.streaming.stream("tweets/search/stream") { |post| break post }

# Give up after five reconnects in a row, and notice a quiet connection sooner
streaming_client = x_client.streaming(max_reconnects: 5, read_timeout: 10)

# Delete the rules that were read, or the ones that match a value
streaming.delete_stream_rules(streaming.stream_rules) # => 2
```

### Responses

A client calls its `on_response` after every request with an `X::Response`, which counts the resources the response returned and reads its rate limits. The API returns rate limit headers with nearly every response, and some writes add limits on the requests of a day. The API bills each post a stream delivers, so a stream calls `on_response` for each one, with that post as the body.

An `X::Response` reads the response itself with `status`, `headers`, and `body`, and an `X::HTTPError` reads a refused one the same three ways. Every error a request raises names the request: `http_method` and `uri` are the method it was sent with and the URL it was sent to, on `X::HTTPError`, `X::NetworkError`, and `X::InvalidResponse` alike, and the message names it too, as `GET /2/users/1: Could not find user` does, so a log of failures says which endpoint each one came from. The message leaves the query out, since a lookup asks for every field of a resource; `uri` keeps it. Header names are lowercase, whatever case the API sent them in, and a header it sent more than once is joined with a comma. `http_response` is the escape hatch for what those do not read: it holds the response as `Net::HTTP` built it. An `X::InvalidResponse`, raised for a successful response whose body is not JSON, reads that response the same three ways.

```ruby
x_client = X::Client.new(**x_credentials, on_response: lambda { |response|
  puts "#{response.http_method} #{response.uri.path}: #{response.resource_counts}" # {"data" => 100, "users" => 42}
  limit = response.rate_limit
  puts "#{limit.remaining} of #{limit.limit} left, resetting in #{limit.reset_in} seconds" if limit
})
```

**One request.** A block passed to `get`, `post`, `put`, or `delete` receives the same `X::Response`, for code that reads the response of one request rather than of every request a client makes. It is passed what `on_response` is passed, at the same points: a response the API refused, before the error is raised, and each attempt of a request that was sent again. A request with both reports to the client's hook first, and both receive the one summary.

```ruby
remaining = nil
user = x_client.get("users/me") { |response| remaining = response.rate_limit&.remaining }
```

**Rate limits.** A request the API refuses for a rate limit raises `X::TooManyRequests`, whose `retry_after` is the number of seconds until the limit resets, or nil when the response does not say. Its `rate_limits` and `rate_limit` read the response's limits as `X::Response` reads them; the limits with no requests left are `exhausted_rate_limits`, and the one `retry_after` waits for is `limiting_rate_limit`. A client can instead wait and retry, up to `max_rate_limit_retries` times, which is 0 by default. It waits only as long as `max_rate_limit_wait`, which is 900 seconds by default, the length of a 15-minute window. A request whose limit resets later, such as a limit on the requests of a day, raises at once. A refusal that does not say when its limit resets waits a minute before the first retry, doubling the wait for each retry after, as X recommends. Up to five seconds are added at random to each wait, since every request of an app shares the app's limits, and so the moment they reset: without the random share, the requests one reset releases would be sent again in one burst, to be refused together once more. They are added to the wait rather than taken off it, since a request sent before the limit resets is refused again, so `max_rate_limit_wait` is the longest reset a request waits for, not the longest it sleeps. Each retry signs the request afresh and passes its response to `on_response`. The API refuses a rate-limited request without acting on it, so retrying a write does not repeat it. A stream is the exception to the default: `X::StreamingClient` reconnects after a rate limit however `max_rate_limit_retries` is set.

```ruby
x_client = X::Client.new(**x_credentials, max_rate_limit_retries: 3, max_rate_limit_wait: 60)
patient_client = x_client.with(max_rate_limit_retries: 0) # raise X::TooManyRequests at once again
```

**Failures the request did not cause.** A 5xx response and a request whose answer never arrived say nothing about the request itself, so the same request may pass a moment later. A client sends one again after an `X::ServerError` or an `X::NetworkError`, `max_retries` times, which is twice by default, waiting up to a second before the first retry and up to twice as long before each after, with a random share of up to half of each wait taken off: a failure of the API fails every request in flight at once, and requests that waited the same time would be sent again together, to fail together once more. Only a `GET`, `PUT`, or `DELETE` is sent again: the API may have acted on a `POST` whose answer never arrived, so that one is left to you. A 4xx is raised at once, since the request is the reason for it. When the response carries a `Retry-After` header, such as a 503 that names the time its endpoint is expected back, the client waits as long as it asks, or as long as the backoff of the attempt, whichever is longer, so a request is never sent again before the API asked for it. A response that asks to be left alone for longer than a minute raises at once rather than hold you for minutes; `error.retry_after` reads the wait it asked for.

```ruby
x_client = X::Client.new(**x_credentials, max_retries: 4) # or 0, to raise at once
```

Whatever `max_retries` is, an idempotent request that fails on a connection the client had kept open for it, which X or a proxy between can close while it is idle, is sent again on a connection opened for it, when the failure says the connection was closed before the request was sent: that request never reached the API, so nothing is repeated. A request that timed out is not sent again this way, since the API may have acted on it; `max_retries` decides whether it is.

See other common usage [examples](https://github.com/sferik/x-ruby/tree/main/examples).

## History and Philosophy

This library is a rewrite of the [Twitter Ruby library](https://github.com/sferik/twitter). Over 16 years of development, that library ballooned to over 3,000 lines of code (plus 7,500 lines of tests), not counting dependencies. The HTTP layer of this library, `x-core`, is about 1,000 lines of code (plus 2,000 test lines) and depends on one gem that is not a default gem, `simple_oauth`, which has no dependencies of its own. That doesn’t mean new features won’t be added over time, but the benefits of more code must be weighed against the benefits of less:

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
* HTTP and HTTPS proxy support, configured or taken from the environment
* HTTP logging
* HTTP timeout configuration
* HTTP headers set per client, per request, or both
* HTTP error handling
* Rate limit handling
* Retrying a request after waiting for its rate limit to reset
* Sending an idempotent request again after a 5xx response or a network failure
* Sending an idempotent request again on a new connection when one kept open had been closed at the other end
* Streaming (filtered stream, volume stream)
* Reconnecting a dropped stream
* Immutable resource objects with identity, references, and hydration
* Lazy, cached, Enumerable cursors that request the maximum page size
* Configurable base URLs for accessing different APIs/versions
* Query strings, JSON bodies, and form bodies built from Ruby values
* Uploading any file with one call, with alt text and subtitles
* Parallel uploading of large media files in chunks
* Parallel batch lookups, as many at a time as you ask for
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
