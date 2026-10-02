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

The gems require Ruby 3.4 or later. Install the gem and add to the application's Gemfile:

    bundle add x

Or, if Bundler is not being used to manage dependencies:

    gem install x

## Architecture

The `x` gem is a thin meta-gem that combines three gems, which are released from this repository in lockstep:

| Gem | What it does | Runtime dependencies |
| --- | --- | --- |
| [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core) | HTTP: authentication, requests, redirects, errors, rate limits, and streaming | `simple_oauth` |
| [`x-uploader`](https://github.com/sferik/x-ruby/tree/main/x-uploader) | Uploads: images, GIFs, videos, and subtitles, with videos and subtitles in chunks, plus profile images and banners | `x-core` |
| [`x-objects`](https://github.com/sferik/x-ruby/tree/main/x-objects) | Resources: `User`, `Post`, `List`, `DirectMessage`, `Space`, `Community`, `Media`, `Poll`, `Place`, and cursors | `x-core` |

`require "x"` loads all three, and mixes the object methods (`find_user`, `find_posts`, `search`, …) and the upload methods (`upload_media`, `add_alt_text`, `update_profile_image`, …) into `X::Client`. Any other request can return objects too, given a resource class as its `object_class`. If you only want raw JSON, depend on `x-core` alone. If you want the objects with an HTTP client of your own, depend on `x-objects` alone: it takes `x-core` for the errors the X gems share, and asks whatever client you give it to make the requests.

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
post.text                              # the full text, even of a post longer than 280 characters
post.created_at                        # => 2026-09-11 12:00:00 UTC
```

**Text.** Objects read every String as the API sends it, and the API escapes `&`, `<`, and `>` as `&amp;`, `&lt;`, and `&gt;` in the text of a post and of a direct message, so `post.text`, `post.expanded_text`, and `message.text` hold them, and will throughout 1.x. Unescape the text to display it:

```ruby
require "cgi/escape"

post.text                              # => "Ruby &amp; Rails"
CGI.unescapeHTML(post.text)            # => "Ruby & Rails"
```

**Nested data.** An object the API nests in a resource, or a list of them, such as `post.entities`, `post.urls`, `post.public_metrics`, `post.attachments`, `media.variants`, or `poll.options`, reads as the API sends it, a frozen Hash keyed by String, or an Array of them, and will throughout 1.x. A later 1.x release may add a reader that returns an object for some of it, as `post.matching_rules` returns `X::MatchingRule`s, but under a new name.

```ruby
post.public_metrics["like_count"]      # => 3, which post.like_count reads too
post.urls.map { |url| url["expanded_url"] }
```

**Any endpoint.** For an endpoint without a method, pass a resource class as the `object_class` of a request. A response that holds one resource comes back as an object, and one that holds a list comes back as an `X::Page` of the page you requested, which reads as an array does, and holds the `next_token` of the page after it. The object holds only the fields you asked for, so `hydrate` fetches the rest.

```ruby
user = x_client.get("users/by/username/sferik", object_class: X::User)
user.followers_count                   # => nil, since the request didn't ask for it
user.hydrate.followers_count           # => 12345

blocked = x_client.get("users/#{user.id}/blocking", object_class: X::User) # => #<X::Page ...>
blocked.first                          # => #<X::User ...>
x_client.get("users/#{user.id}/blocking", params: {pagination_token: blocked.next_token}, object_class: X::User)
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

**Pagination.** Collections are `X::Cursor` objects, which include `Enumerable`, remember the client that fetched them, and fetch pages lazily. Iterating requests the maximum page size, and pages are cached, so iterating twice costs no extra requests. `first(n)` and `take(n)` request a page of `n` instead, raised to the endpoint's minimum. `published_count` reads the number the API publishes for a collection, such as a user's `followers_count`, without paging through it, while `count` and `size` page through the whole collection, as `Enumerable` does. `refresh` returns a cursor with an empty cache, and `ids` fetches nothing but identifiers.

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
x_client.search_spaces("ruby", state: "live").first(10)
x_client.current_user.home_timeline.first(10)
```

**Stubs.** `from_id` refers to a resource without a request, so a cursor can be built from an identifier alone. A reference the response did not expand is a stub too, and `stub?` tells the two apart.

```ruby
X::User.from_id(7505382, client: x_client).followers.ids
post.author.stub?                      # => false when the response included the author
X::User.hydrate_all(posts.map(&:author), client: x_client) # looks up the stubs in one batch
message.peer(x_client.current_user)    # the other participant of a direct message
```

**Costs.** The X API bills each resource a request returns, so the size of a page is the size of the bill. `first(n)` and `take(n)` read only what they return. Iterating a cursor, `to_a`, and `ids` read the whole collection, up to 1,000 users a page for followers and following. `count` and `size` read the whole collection too, a request per page, billed for every resource, so counting a user with a million followers reads a million users in a thousand requests. `published_count` reads the number the API publishes instead, for a user's followers, followed users, and list memberships, and for a list's members and followers, which costs nothing when the user or list holds it and one lookup when it is a stub, and it returns nil for any other collection. The published number counts what the collection holds, which can differ from what reading it finds, since the API leaves out what the authenticated user cannot see. Other `Enumerable` methods, such as `find`, `include?`, and `lazy`, cannot know how much they will read, so they request the largest page too; pass `max_results:` to read less per request. `user.follows?(other)` takes one lookup when either user is the authenticated user, by reading the other's `connection_status`, and otherwise scans the users `user` follows. The API has no lookup for a list membership, so `list.member?(user)` scans: the members of a private list, and for a public list, whichever is smaller of its members and the lists the user is on, as `member_count` and `listed_count` tell. Pass either scan `max_pages:` to read no more pages than that: one that reaches the limit with pages left raises `X::PageLimitReached`, rather than answer from the pages it read.

```ruby
user.followers.first(10)               # ten users
user.followers.published_count         # the user's followers_count, reading no follower
user.followers.count                   # every follower, a request per 1,000
user.muting.published_count            # => nil, since the API publishes no number
x_client.current_user.follows?(other)  # one lookup
other.follows?(x_client.current_user)  # one lookup
other.follows?(someone)                # scans everyone other follows
other.follows?(someone, max_pages: 5)  # scans five pages at most, or raises X::PageLimitReached
user.followers(max_results: 100).find { |follower| follower.verified? }
```

The API bills a resource once per UTC day, however often it is read, and bills only the resources a response returns as data, not the ones it includes, so expanding `post.author` costs nothing extra. Batch lookups ask for each ID once. Reads of the authenticated user's own data cost a fifth as much as other reads when that user owns the app: their posts, mentions, likes, bookmarks, followers, following, blocks, mutes, and lists. So `x_client.current_user.posts` is cheaper than searching for `from:sferik`. Actions take the authenticated user's ID from the prefix of an OAuth 1.0a access token, and so need no request to `users/me`.

Writes are billed by the request, and cost more than reads. Creating a post costs $0.015, or $0.20 when its text holds a URL, so a link costs more than ten times as much as the post around it. A like, repost, follow, or direct message costs $0.015, and undoing one costs $0.01. Prices change, so check the [pricing page](https://docs.x.com/x-api/getting-started/pricing) before a large run.

**Post usage.** `post_usage` reports how many posts the app's project has read this billing cycle, against its monthly cap, and how many it read each day.

```ruby
usage = x_client.post_usage(days: 30)
usage.project_cap - usage.project_usage # the posts left to read this cycle
usage.daily                            # => {2026-09-14 00:00:00 UTC => 1234, ...}
usage.daily_by_app                     # the same, keyed by the ID of each of the project's apps
```

**Counting posts.** `count_posts` counts the posts from the last seven days that match a query, and `count_all_posts` counts every post, which needs full-archive access. Each costs one request per page of periods, whatever the count, and a count of many years of the archive takes many pages, so `count_all_posts` and `count_all_posts_by_period` take `max_pages:`, past which they raise `X::PageLimitReached`. The counts and usage endpoints refuse OAuth 1.0a, so a client that signs with it makes those requests through `app_only`, a copy of itself that authenticates as the app. The client fetches the app's bearer token the first time and reuses it.

```ruby
x_client.count_posts("ruby")           # => 12345
x_client.post_counts("ruby", granularity: "hour") # => {2026-09-14 12:00:00 UTC...2026-09-14 13:00:00 UTC => 42, ...}
X::Post.count_all("ruby", client: x_client, start_time: "2020-01-01T00:00:00Z")
X::Post.count_all("ruby", client: x_client, max_pages: 3) # three requests at most
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
x_client.find_all_users(ids) { |problem| warn problem.detail if problem.not_found? }
x_client.find_user!("nobody")          # raises X::ResourceNotFound: Could not find X::User nobody: Could not find user with username: [nobody].
```

**Parallel requests.** Batch lookups split the IDs into groups of 100, the API maximum, and request the groups in parallel. Paginated endpoints return a token for the next page with each page, so their pages must be fetched in order. `prefetch` fetches the next page in a background thread while you process the current one. It is opt-in because it spends one extra request when you stop iterating early.

```ruby
x_client.find_all_users(follower_ids)                       # parallel batches of 100, in the order asked for
user.followers.prefetch.each { |follower| process(follower) }
```

**Actions.** Actions are taken as the authenticated user. They take a resource or its identifier, an Integer or a String of digits, and raise `ArgumentError` for anything else, such as a username, so look a user up with `find_user` first.

```ruby
me = x_client.current_user             # fetched once per client
me.follow(user)
me.block(user)
me.like(post)
me.repost(post)
me.bookmark(post)

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
v1_client = x_client.copy(base_url: "https://api.x.com/1.1/")

# Post a form
v1_client.post("account/settings.json", form: {lang: "en"})

# Authenticate as the app, with a bearer token fetched once with the API key and secret
x_client.app_only.get("tweets/search/stream/rules")

# Authenticate with OAuth 2.0, refreshing the access token when it expires or the API rejects it,
# and store the tokens of each refresh, since X accepts a refresh token only once
oauth2_client = X::Client.new(client_id: "ID", client_secret: "SECRET", access_token: "TOKEN", refresh_token: "REFRESH",
  expires_at: Time.now + 7200, on_token_refresh: ->(tokens) { store(tokens.access_token, tokens.refresh_token, tokens.expires_at) })

# Authenticate with a scheme of your own: subclass X::Authenticator and return the headers that authenticate a request
class VaultAuthenticator < X::Authenticator
  def header(_request) = {AUTHENTICATION_HEADER => "Bearer #{Vault.read("x/bearer_token")}"}
end
vault_client = X::Client.new(authenticator: VaultAuthenticator.new)

# Ask a user to authorize the app with OAuth 2.0 and PKCE, keeping the state and code verifier until X redirects back
authorization = X::OAuth2Authorization.new(client_id: "ID", redirect_uri: "https://example.com/callback",
  scopes: %w[tweet.read tweet.write users.read offline.access])
session[:state] = authorization.state
session[:code_verifier] = authorization.code_verifier
redirect_to authorization.url

# Then, where X redirects back, exchange the code for a client that acts for the user; on_token_refresh is passed the
# tokens of the exchange, whose refresh_token is nil without offline.access, and those of each refresh after
authorization = X::OAuth2Authorization.new(client_id: "ID", redirect_uri: "https://example.com/callback",
  state: session[:state], code_verifier: session[:code_verifier])
user_client = authorization.client(request.url, on_token_refresh: ->(tokens) { store(tokens.refresh_token) })

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
x_client.keep_alive_timeout = 5

# Send headers with every request, such as one that names your application. They are defaults: a header of the same
# name passed to a request, or to a stream, is sent in place of the client's, and each of the client's is sent in
# place of a default of the gem, such as its User-Agent, whatever the case each is named in.
named_client = X::Client.new(headers: {"User-Agent" => "my-app/1.0 (+https://example.com)"}, **x_credentials)
named_client.get("users/me", headers: {"X-Trace" => "abc"}) # sends both
# with(headers:) replaces the headers of the client rather than adding to them, so give the copy every header it sends
traced_client = named_client.with(headers: named_client.headers.merge("X-Trace" => "abc")) # sharing its connections

# Send requests through a proxy. A client that is given none takes the proxy the environment names for the scheme of
# each request, in https_proxy or http_proxy, and reaches the hosts that no_proxy names directly.
proxied_client = X::Client.new(proxy_url: "http://user:password@proxy.example.com:8080", **x_credentials)

# Close the connections a client keeps open between requests, which the copies `with` makes of it share when they
# open their connections alike; a later request opens one again
x_client.close
```

### Media

```ruby
# The media category is inferred from the file: an image, an animated GIF, a video, or subtitles.
# A GIF with a single frame is uploaded as an image, since X processes only animated GIFs as GIFs.
media = x_client.upload_media("cat.jpg", alt_text: "A cat asleep on a keyboard")
media.id                               # => 1880028106020515840, and media["id"] reads it as the API gave it
media.expires_at                       # => 2026-09-19 12:00:00 UTC, after which it cannot be attached to a post
x_client.create_post("Look at this cat", media_ids: [media])
x_client.find_media(media.media_key).url # the X::Media it became, as a post refers to it

# A video is uploaded in chunks, four at a time unless concurrency says otherwise, and upload waits until a video or
# an animated GIF has been processed, for up to ten minutes unless processing_timeout says otherwise
video = x_client.upload_media("cat.mp4")
video.ready?                           # => true, since upload_media waited; state is "succeeded"
subtitles = x_client.upload_media("cat.srt")
x_client.add_subtitles(video, subtitles, "EN", display_name: "English")
x_client.create_post("Look at this cat move", media_ids: [video])

# Update the profile image and banner of the authenticated user. These two call the API v1.1, which the API v2 has
# no endpoint for, and return nothing to read: look the user up to read the image and banner it now has.
x_client.update_profile_image("avatar.png")
x_client.update_profile_banner("banner.png")

# Media is a path, or an IO open on it. Media given as a String or a Pathname is read from the file it names, and
# media given as a File or a Tempfile through that IO, even once the Tempfile is unlinked, or from the file it names
# once it is closed, a chunk at a time, so media of any size uploads without being held in memory. A String that holds
# the contents of media, rather than its path, raises ArgumentError: wrap the contents in a StringIO. A String is
# read as a path on this machine, so never pass one a user gave, such as a parameter of a form, which could name any
# file the process can read, and upload it to X: pass the IO of the file the user uploaded instead.
x_client.upload_media(Pathname("cat.jpg"))
File.open("cat.mp4", "rb") { |file| x_client.upload_media(file) }

# Media given as any other IO, such as a StringIO, is read to its end and held. Its category is read from the bytes
# it begins with, as the category of a file is before its name: a GIF, PNG, JPEG, BMP, TIFF, WebP, MP4, QuickTime, WebM, MPEG transport
# stream, or WebVTT file is recognized by its signature. Pass media_category for anything else, such as SubRip subtitles, which begin
# with nothing a text file could not.
x_client.upload_media(StringIO.new(png))
x_client.upload_media(StringIO.new(srt), media_category: "subtitles")
```

Each of these methods calls an uploader with the client: `upload_media`, `chunked_upload_media`, which uploads in chunks and returns before X processes the media, `await_media_processing`, and `await_media_processing!`, which raises `X::MediaProcessingFailed` where the other returns the status of processing that failed, or that ended in a state X does not document, call `X::Uploader::MediaUpload`, `add_alt_text` and `add_subtitles` call `X::Uploader::Metadata`, and `update_profile_image` and `update_profile_banner` call `X::Uploader::Account`. The uploaders take an `X::Client` as `client:`, as in `X::Uploader::MediaUpload.chunked_upload("cat.mp4", client: x_client, chunk_size: 5 * 1024 * 1024)`, which `x_client.chunked_upload_media("cat.mp4", chunk_size: 5 * 1024 * 1024)` calls.

`upload_media` uploads an image in a single request, which takes no chunks, so it ignores `chunk_size:`, `concurrency:`, and `media_type:` for one; `chunked_upload_media` uploads in chunks whatever the media, and is the way to upload without waiting for X to process it.

A video uploads in chunks of 4 MB, each a request of its own, which a rate limit can refuse. A client retries a request refused for a rate limit only `max_rate_limit_retries` times, 0 by default, so a chunk refused fails the upload with `X::ChunkedUploadFailed`, which holds the media it initialized. Upload a large video with a client whose `max_rate_limit_retries` is set, such as `X::Client.new(**x_credentials, max_rate_limit_retries: 3)`, so that a rate limit is waited out, up to the client's `max_rate_limit_wait`, rather than fail the upload.

What each returns: `upload_media`, `chunked_upload_media`, `await_media_processing`, and `await_media_processing!` return an `X::UploadedMedia`, which reads as the Hash the API answered with as well as by its own methods; `add_alt_text` and `add_subtitles` return the media they describe as an `X::UploadedMedia`, the video for `add_subtitles`, so either can be passed on to `create_post`; and `update_profile_image` and `update_profile_banner` return nothing to read, `nil`: they are the only methods in these gems that call the v1.1 API, whose user no object of the object layer reads, so `current_user!` reads the image and banner the user now has.

### Streaming

A stream holds a connection open instead of answering a request, so `X::StreamingClient` handles one, and `streaming` builds it from a client. It shares the client's credentials, base URL, parsing classes, and `on_response` hook, and keeps the settings a long-lived connection needs: `read_timeout`, 30 seconds by default, and `max_reconnects`.

The stream endpoints take app-only authentication, so a client that signs with OAuth 1.0a streams with the bearer token that `app_only` holds. A client that authenticates with OAuth 2.0 as a user holds no credentials of the app, so X refuses its streams with 403 Forbidden; stream with a client built from the app's bearer token, or its API key and secret, instead.

X holds a stream open indefinitely, but drops it for deploys, network trouble, and slow readers. A stream that ends, drops, is refused a connection, or that X disconnects with an `operational-disconnect` reconnects at once, then waits a quarter second longer each attempt, up to 16 seconds; one that ends within a line drops what it sent of the line, which is neither parsed nor passed to `on_response`, and reconnects the same way. A server error, a 408 Request Timeout, a 409 Conflict, or a line that is not JSON waits 5 seconds, doubling each attempt, up to 320 seconds. A rate limit backs off from a minute, doubling each attempt, up to 320 seconds, as X asks, and waits longer for a limit that resets later, but raises `X::TooManyRequests` at once rather than wait longer than the `max_rate_limit_wait` of the client, 900 seconds by default, so that a limit on the connections of a day does not hold a stream closed for hours. Delivering a post starts the count over. A stream reconnects without limit by default; set `max_reconnects` to give up after that many attempts in a row, when it raises the error of the last, an `X::NetworkError` for a stream that ended or dropped, so a stream never returns but for a `break` from its block, or a `stop`.

> [!IMPORTANT]
> Reconnects are unlimited by default, and silent, so a stream that cannot connect at all, as for a host that does not resolve or a network that is down, keeps trying every 16 seconds for as long as it runs. Only a certificate that does not verify, which will not verify on the next attempt either, raises at once, an `X::NetworkError` whose `cause` is the `OpenSSL::SSL::SSLError`. To give up on the rest, set `max_reconnects`, or pass `on_reconnect`, which is called before each reconnect with the error that dropped the stream, never nil, and the seconds it waits, and can `stop` the stream or raise. It is called with those two arguments, and no others, by every release of 1.x.

**The rules of the filtered stream.** The filtered stream delivers the posts that match the rules of the app, which belong to the stream and are read and changed through a streaming client: `stream_rules` reads them, `add_stream_rules` adds them, and `delete_stream_rules` deletes them, each authenticating as the app as a stream does. A rule to add is a `value` and the `tag` it is labelled with, or a String, which is the value of a rule with no tag. A rule is deleted by the identifier it was given, so what `stream_rules` returned deletes itself, or by the value it matches, so what `add_stream_rules` was given deletes what it added. An `X::MatchingRule` names a rule by its identifier too, so the `matching_rules` of a post of `x-objects` delete the rules the post matched, but anything else with an `id`, such as a post, raises `ArgumentError` before a request, since it would delete whichever rule shared its identifier. `dry_run: true` has the API check the rules and change none of them. The API changes the rules it can and reports the rest, such as a rule the app already has or does not have, and both `add_stream_rules` and `delete_stream_rules` yield each problem it reported to a block.

**Stopping a stream.** A stream runs until its block stops it. `break` out of the block to stop the stream and return a value, or `throw` to unwind to a `catch` further out; neither reconnects. An error raised by the block stops the stream too, even one a dropped connection would have reconnected after, and reaches the caller unchanged, as does an error raised by `on_response` or by the class that builds each object. A `StopIteration` is an error like any other here, so a block that exhausts an `Enumerator` of its own hears about it rather than ending the stream in silence. A block runs only when a post arrives, so it cannot stop a stream that delivers nothing; `stop` can, from any thread: it stops every stream the streaming client runs, the next time each waits on the API, and each returns nil. A block, or an `on_response`, that is running when the stream is stopped runs to its end first.

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

# Stop a stream that runs in another thread, even one that delivers nothing
streaming = x_client.streaming
reader = Thread.new { streaming.stream("tweets/search/stream") { |post| queue << post } }
streaming.stop # => 1
reader.value   # => nil

# Give up after five reconnects in a row, and notice a quiet connection sooner
streaming_client = x_client.streaming(max_reconnects: 5, read_timeout: 25)

# Log each reconnect, and give up on a stream that has failed to connect for minutes
streaming_client = x_client.streaming(on_reconnect: lambda do |error, wait|
  warn "#{error.class}: #{error.message}; reconnecting in #{wait} seconds"
  streaming_client.stop if error.is_a?(X::NetworkError) && wait >= 16
end)

# Delete the rules that were read, or the ones that match a value
streaming.delete_stream_rules(streaming.stream_rules) # => 2
```

### Responses

A client calls its `on_response` after every request with an `X::Response`, which counts the resources the response returned and reads its rate limits. The API returns rate limit headers with nearly every response, and some writes add limits on the requests of a day. The API bills each post a stream delivers, so a stream calls `on_response` for each one, with that post as the body.

An `X::Response` reads the response itself with `status`, `headers`, and `body`, and an `X::HTTPError` reads a refused one the same three ways. Every error a request raises names the request: `http_method` and `uri` are the method it was sent with and the URL it was sent to, on `X::HTTPError`, `X::NetworkError`, `X::InvalidResponse`, and `X::TooManyRedirects` alike, and the message names it too, as `GET /2/users/1: Could not find user` does, so a log of failures says which endpoint each one came from. The message leaves the query out, since a lookup asks for every field of a resource; `uri` keeps it. Header names are lowercase, whatever case the API sent them in, and a header it sent more than once is joined with a comma. `http_response` is the escape hatch for what those do not read: it holds the response as `Net::HTTP` built it. An `X::InvalidResponse`, raised for a successful response whose body is not JSON, is an `X::HTTPError` too, and reads that response the same three ways; its `problem` is nil and its `problems` are empty.

```ruby
x_client.on_response = lambda do |response|
  puts "#{response.http_method} #{response.uri.path}: #{response.resource_counts}" # {"data" => 100, "users" => 42}
  limit = response.rate_limit
  puts "#{limit.remaining} of #{limit.limit} left, resetting in #{limit.reset_in} seconds" if limit
end
```

**One request.** A block passed to `get`, `post`, `put`, or `delete` receives the same `X::Response`, for code that reads the response of one request rather than of every request a client makes. It is passed what `on_response` is passed, at the same points: a response the API refused, before the error is raised, and each attempt of a request that was sent again. A request with both reports to the client's hook first, and both receive the one summary.

```ruby
remaining = nil
user = x_client.get("users/me") { |response| remaining = response.rate_limit&.remaining }
```

**Rate limits.** A request the API refuses for a rate limit raises `X::TooManyRequests`, whose `retry_after` is the number of seconds the response asks a request to wait in its `Retry-After` header, or else the number until the limit that refused it resets, or nil when the response says neither; the header counts from when the response was sent, so it holds however far your clock is from the API's. Its `rate_limits` and `rate_limit` read the response's limits as `X::Response` reads them; the limits with no requests left are `exhausted_rate_limits`, and the one that resets last, which `reset_in` counts down to, is `limiting_rate_limit`. A client can instead wait and retry, up to `max_rate_limit_retries` times, which is 0 by default. It waits only as long as `max_rate_limit_wait`, which is 900 seconds by default, the length of a 15-minute window. A request whose limit resets later, such as a limit on the requests of a day, raises at once, as does one refused for the usage cap of the project, which lasts until the month ends, and which `error.problem&.usage_capped?` tells apart from a rate limit. A refusal that does not say when its limit resets waits a minute before the first retry, doubling the wait for each retry after, as X recommends. Up to five seconds are added at random to each wait, since every request of an app shares the app's limits, and so the moment they reset: without the random share, the requests one reset releases would be sent again in one burst, to be refused together once more. They are added to the wait rather than taken off it, since a request sent before the limit resets is refused again, so `max_rate_limit_wait` is the longest reset a request waits for, not the longest it sleeps. Each retry signs the request afresh and passes its response to `on_response`. The API refuses a rate-limited request without acting on it, so retrying a write does not repeat it. A stream is the exception to the default: `X::StreamingClient` reconnects after a rate limit however `max_rate_limit_retries` is set, though it too waits no longer than `max_rate_limit_wait`, and does not reconnect after the usage cap.

```ruby
x_client = X::Client.new(**x_credentials, max_rate_limit_retries: 3, max_rate_limit_wait: 60)
x_client.max_rate_limit_retries = 0    # raise X::TooManyRequests at once again
```

See other common usage [examples](https://github.com/sferik/x-ruby/tree/main/examples).

## History and Philosophy

This library is a from-scratch rewrite of the [Twitter Ruby library](https://github.com/sferik/twitter). Rather than carry that library’s design forward, it aims to be more minimal and modular: a lightweight core, `x-core`, that handles HTTP and little else, with optional gems, `x-uploader` and `x-objects`, built on top of it. You pay only for what you use. An application that needs nothing but raw JSON can depend on `x-core` alone and never load the code for uploads or objects.

That doesn’t mean new features won’t be added over time, but the benefits of more code must be weighed against the benefits of less:

* Less code is easier to maintain.
* Less code means fewer bugs.
* Less code runs faster.

In the immortal words of [Ezra Zygmuntowicz](https://github.com/ezmobius) and his [Merb](https://github.com/merb) project (may they both rest in peace):

> No code is faster than no code.

## Features

If this entire library is implemented in under 3,000 lines of code, why should you use it at all vs. writing your own library that suits your needs? If you feel inspired to do that, don’t let me discourage you, but this library has some advanced features that may not be initially apparent, including:

* OAuth 1.0 Revision A
* OAuth 2.0
* App-only authentication
* Thread safety
* Persistent HTTP connections, reused across requests to the same host
* HTTP redirect following
* HTTP and HTTPS proxy support
* HTTP logging
* HTTP timeout configuration
* HTTP error handling
* Rate limit handling
* Retrying a request after waiting for its rate limit to reset
* Streaming (filtered stream, sample stream)
* Reconnecting a dropped stream
* Immutable resource objects with identity, references, and hydration
* Lazy, cached, Enumerable cursors that request the maximum page size
* Configurable base URLs for accessing different APIs/versions
* Query strings, JSON bodies, and form bodies built from Ruby values
* Uploading any file with one call, with alt text and subtitles
* Parallel uploading of large media files in chunks
* Parallel batch lookups
* Partial errors reported by a response that otherwise succeeded

## Versioning

The gems follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html), and 1.x promises their public interface: every class, module, constant, method, and keyword argument whose documentation says `@api public`, with the types the RBS signatures each gem ships give them, which declare that interface alone; the signatures of its internals, in `sig/internal`, are not shipped. A minor release may add to that interface and a patch release may fix it, but only a major release removes or changes what it promises.

Anything documented `@api private` is internal to the gem that declares it, even where Ruby lets you call it, as is every private constant, and either may change or go away in any release. Most of it sits in the module of its gem, such as `X::Core`, beside mixins that are public, such as `X::Objects::API` and `X::Uploader::MediaUpload`, so it is the documentation, not the namespace, that says which is which.

The four gems are released together at the same version, and each depends on the ones it needs, `x-uploader` and `x-objects` on `x-core` and `x` on all three, with a constraint of that version or a later one of the same major version, such as `>= 1.0.0, < 2` for 1.0.0, so a later release of 1.x of one installs beside the others, but never an earlier release than its own. They are built and tested together at each version, so upgrade them together, as depending on `x` does.

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
