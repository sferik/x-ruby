# x-resources

The object layer of the [`x` gem](https://github.com/sferik/x-ruby): immutable, thread-safe resource classes for the [X API](https://developer.x.com) with identity, references, hydration, cached pagination, and parallel batch lookups.

It makes no HTTP requests itself: it asks a client to make them. Its one runtime dependency is [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core), for `X::Error`, the base class of every error the X gems raise, `X::UnsupportedOperation`, which it raises for what the API offers no way to do, `X::UnsupportedFormat`, which it raises for what `Marshal` wrote in a format it does not read, and `X::Problem`, which describes the partial errors of a response.

Most applications should install [`x`](https://rubygems.org/gems/x), which wires this gem to the HTTP client from [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

## Installation

`x-resources` requires Ruby 3.4 or later.

    bundle add x-resources

## Resources

| Class | References | Collections | Class collections |
| --- | --- | --- | --- |
| `X::User` | `pinned_post`, `most_recent_post`, `affiliated_with` | `followers`, `following`, `affiliates`, `blocking`, `muting`, `posts`, `home_timeline`, `mentions`, `liked_posts`, `bookmarks`, `bookmark_folders`, `owned_lists`, `list_memberships`, `followed_lists`, `pinned_lists` | `search` |
| `X::Post` | `author`, `in_reply_to_user`, `community`, `replied_to`, `quoted`, `reposted`, `references`, `media`, `polls`, `place` | `liked_by`, `reposted_by`, `reposts`, `quotes` | `search`, `search_all`, `reposts_of_me` |
| `X::List` | `owner` | `members`, `followers`, `posts` | |
| `X::DirectMessage` | `sender`, `participants`, `references`, `media` | | `all`, `with`, `in` |
| `X::Space` | `creator`, `hosts`, `speakers`, `invited_users`, `topics` | `posts`, `buyers` | `search` |
| `X::Community` | | | `search` |
| `X::Media` | | | |
| `X::Poll`, `X::Place`, `X::Topic`, `X::BookmarkFolder` | | | |

Every class but `X::Poll`, `X::Place`, `X::Topic`, and `X::BookmarkFolder`, which the API has no lookup for, is looked up with `find`, as in `X::Media.find("3_1880028106020515840", client:)`, which looks media up by its media key. A collection is an `X::Cursor`, read from a resource, as in `user.followers`, and a class collection is one read from the class with a client, as in `X::Post.search("ruby", client:)`. `user.bookmarks(folder:)` reads the posts in one of the `bookmark_folders`, and `X::Space.find_all_by_creator` looks up the spaces of many users by the users who created them.

Trends are not resources, since they have no identifier: `X::Trend.at(1, client:)` reads the topics trending in a place, named by its Yahoo! Where On Earth identifier, and `X::PersonalizedTrend.all(client:)` the topics X picks for the authenticated user, each returning an Array. A post of the filtered stream reads the rules it matched with `matching_rules`, as `X::MatchingRule` values, and `X::Media#media_id` reads the numeric media ID that the media key of `X::Media#id` names.

`X::User.find` reads an Integer or a user as an identifier and a String as a username, so a handle of digits needs `X::User.find_by_username` (or `find_by_username!`, and `client.find_user_by_username`) to say which is meant, and an identifier read as a String, as from a response or an environment variable, needs `X::User.find_by_id` (or `find_by_id!`, and `client.find_user_by_id`).

A lookup of one resource that does not exist, or is deleted or suspended, returns nil, and its bang form, such as `X::User.find!` or `client.find_user!`, raises `X::MissingResource`, whether X answers 200 OK with no data or a 404 that reports the resource as not found. The `X::NotFound` of such a 404 is the `cause` of the error, and `hydrate` and `refresh` return nil for such a resource too. A client of your own must name the request its 404 answers: raise `X::NotFound` with the `http_method:` and the `uri:` (a `URI`, not a String) of the request, and with the response, either as `http_response:` or as `body:` plus `headers:` that hold its JSON `content-type`, as `X::Client` does. A 404 built without them raises `X::NotFound` from the finder, since a 404 is read as a missing resource only when it answers the lookup itself and reports the resource as not found. Any other 404, such as one from a client pointed at the wrong host or API version, or one to another request, such as `current_user`, a `find_all`, or a collection, raises `X::NotFound`.

The space endpoints refuse OAuth 1.0a, so `X::Space.find`, `find_all`, `find_all_by_creator`, `search`, and `space.posts` make their requests with the client's app-only client when it has one, which a client signed in with OAuth 2.0 as a user has when it holds the app's bearer token, or its API key and secret, and with the client itself when it has none, such as one signed in with OAuth 2.0 as a user that holds neither, which the space endpoints take. Bookmarking and unbookmarking a post, and `space.buyers`, take only OAuth 2.0 user context, which the gem cannot route around; reading bookmarks and bookmark folders takes OAuth 1.0a too.

## The client contract

Any object that responds to `get`, `post`, `put`, and `delete` can be the client. Each method takes a path relative to the API base URL and keyword options, and returns the parsed JSON body. The path carries the query, which the object layer builds, so a client is never passed a `params:` of its own. `post` and `put` also take the request body as an optional second argument: a Hash, which the client sends as JSON, as `X::Client` does, or a String the client sends as it is. The object layer always passes `array_class: Array, object_class: Hash`, so a client's own parsing defaults can't change what it receives. `X::Client` from `x-core` satisfies this contract, which the `X::Resources::_Client` interface in [`sig/x-resources.rbs`](https://github.com/sferik/x-ruby/blob/main/x-resources/sig/x-resources.rbs) states for a type checker.

`array_class:` and `object_class:` are the only keywords the object layer passes, but a release within 1.x may pass any other keyword `X::Client` takes for the same method, such as `params:` or `headers:`, so take the keywords with `**options`, as below, rather than name the two alone.

Five more methods are asked for where they save a request, and a client that answers none of them is asked for none:

| Method | What it is asked for | Without it |
| --- | --- | --- |
| `app_only` | a client that authenticates as the app, for the endpoints that refuse the OAuth 1.0a of a user, such as the spaces, counts, and usage endpoints | the request is made with the client itself, which the API refuses when it signs with OAuth 1.0a |
| `authenticator` | the `user_id` the authenticator names, since an OAuth 1.0a access token begins with the identifier of the user who authorized it | `current_user_id` looks the user up, which costs a request |
| `current_user_id` | the authenticated user of a check that either user may be, which `X::Resources::API` answers already | `user.follows?(other)` scans the users `user` follows rather than reading `connection_status` in one lookup |
| `memoized` | the value kept under a Symbol key, such as `:x_resources_current_user_id`, for the authenticator the client holds, or nil if none is kept | the value is read from the `@x_resources_current_user_id` instance variable of the client |
| `memoize` | to keep a value under a Symbol key, passed as `memoize(key, value)`, for the authenticator the client holds | the value is kept in the `@x_resources_current_user_id` instance variable of the client, or not at all when the client is frozen |

The object layer reads the errors of `x-core`, so a client raises them for a request that fails: `X::Unauthorized` or `X::Forbidden` for credentials the API refuses, which `follows?` reads as a client that knows no authenticated user, and scans instead, and `X::UnsupportedOperation` from an `app_only` that holds no credentials of the app, which the space endpoints, the trends of a place, and the count of recent posts read as a client that requests as itself, since they take OAuth 2.0 as a user too, and which the count of the full archive and the usage of the project read so too, though they take the app alone, so the API refuses them with 403 Forbidden, which raises `X::Forbidden`. Any other error ends the call it was raised in.

```ruby
require "x/resources"

class MyClient
  include X::Resources::API # adds find_user, find_user_by_username, find_user_by_id, find_all_users, current_user, current_user!, find_post, find_all_posts, search_posts, find_list, find_media, find_space, find_community, find_dm, follow, like, ...

  def get(path, **options)
    # Send the request and return the response body, parsed into options[:array_class] and options[:object_class]
  end

  def post(path, body = nil, **options)
    # Send the body as JSON and return the response body, parsed as get parses it
  end

  def put(path, body = nil, **options)
    # Send the body as JSON and return the response body, parsed as get parses it
  end

  def delete(path, **options)
    # Send the request and return the response body, parsed as get parses it
  end
end
```

You can also call the resource classes directly:

```ruby
X::User.find("sferik", client:)
X::Post.find_all(ids, client:)
X::Post.search("ruby", client:)
```

## Building objects from any response

`from_response` builds a resource from a parsed response, or an `X::Page` of them when its data is a list, which holds the `meta` of the response, such as its `next_token`, and the problems it reported. A lookup of several resources, such as `users?ids=`, that finds none of them builds an empty page of the problems it reported, as one that finds some builds a page of those. `X::Client` from `x-core` calls it when a resource class is the `object_class` of a request, passing the parsed body and itself:

```ruby
user = client.get("users/by/username/sferik", object_class: X::User)
```

An object built this way is not hydrated, because the request may have asked for only some fields, so `hydrate` fetches the full resource. The lookups, batch lookups, and cursors in this gem request every field, so what they return is already hydrated, unless they are given a parameter that overrides a default field or expansion parameter to leave some of its values out, such as `"user.fields": "name"`: what they return then is not hydrated either, so `hydrate` fetches the rest. A parameter that asks for every default value, in any order, and for more besides, such as `"post.fields": [*X::Post::FIELDS, "non_public_metrics"]`, still returns hydrated resources, which keep the fields it added.

The defaults are the `FIELDS` and `EXPANSIONS` of each class, and a minor release may add to them what the API adds, so that a lookup with the defaults asks for it too. A resource looked up with a list of your own, even one that named every field when it was written, then leaves out what was added, so it stops counting as hydrated, and `hydrate` costs a lookup it did not cost before, as does a resource written with `Marshal` or YAML by a release that asked for less. To ask for more than the defaults, add to what `default_params` gives, as the example above adds to `X::Post::FIELDS`, rather than list every value.

A resource reports the problems of its response that concern it with `problems`: those whose `resource_id` or `value` is its identifier, or that of a resource it refers to directly, such as the author of a post, and those that name no identifier. A page of a cursor reports every problem of its response, and a finder yields every one to its block. To tell which resource a problem is about, ask it with `X::Problem#about?`, as `quoted = post.quoted and post.problems.find { |problem| problem.about?(quoted) }` does, since `about?` takes a resource or an identifier, and not nil: it compares the identifiers as Strings, where `problem.resource_id == post.quoted.id` compares a String with an Integer and is always false.

## Text

A resource reads every String as the API sends it, and the API escapes `&`, `<`, and `>` as `&amp;`, `&lt;`, and `&gt;` in the text of a post and of a direct message, so `X::Post#text`, `X::Post#expanded_text`, and `X::DirectMessage#text` hold them, and will throughout 1.x. Unescape the text to display it:

```ruby
require "cgi/escape"

post.text                              # => "Ruby &amp; Rails"
CGI.unescapeHTML(post.text)            # => "Ruby & Rails"
```

## Nested data

A reader of an object the API nests in a resource, or of a list of them, returns it as the API sends it: a frozen Hash keyed by String, or an Array of them, as `Hash[String, untyped]` in the signatures. A response that holds anything else in its place, such as a String where the API documents an object, raises `X::InvalidAttribute` from the reader. Among them are the `entities`, `urls`, `public_metrics`, `edit_controls`, `attachments`, and `withheld` of a post, the `variants` of media, the `options` of a poll, and the `subscription` and `affiliation` of a user. Others return objects, as `post.matching_rules` returns `X::MatchingRule`s and `space.topics` returns `X::Topic`s.

```ruby
post.public_metrics["like_count"]      # => 3, which post.like_count reads too
post.urls.map { |url| url["expanded_url"] }
media.variants.max_by { |variant| variant["bit_rate"].to_i }&.fetch("url")
```

Each reader of nested data returns a frozen Hash keyed by String, or an Array of them, throughout 1.x. A release within 1.x may add a reader that returns an object for some of that data, but under a new name, never in place of one of these.

## How it works

* **Immutability.** Resources, pages, and cursors are frozen, and so are the arrays a lookup returns, those a cursor reads with `to_a`, `entries`, `first`, `take`, and `ids`, and the `items` of a page, which its `to_a` and `entries` return. Their attributes are deep-frozen copies of the response.
* **Identity.** `==`, `eql?`, and `hash` compare class and ID.
* **Identity map.** Each response gets one map. A reference resolves to the included object when the response expanded it, or to a stub otherwise, and every reference to the same resource in that response is the same object.
* **Hydration.** `hydrate` fetches the full resource once per object, under a lock, and memoizes it. `refresh` replaces the memoized value.
* **Cursors.** Pages are fetched lazily under a lock and cached, so concurrent iteration fetches each page once. A page that names the token of a page already fetched as its next raises `X::UnreadableResponse`, rather than page forever. `refresh` returns a cursor with an empty cache. `prefetch` returns a cursor that fetches the next page in a background thread; a page the thread fails to fetch raises the error it failed with when it is reached, rather than being requested again.
* **Parallelism.** `find_all` splits IDs into batches of 100 and fetches the batches on up to 4 threads, or the `concurrency:` it is given, preserving order: it returns a resource for each ID that was found, so an ID given twice comes back twice, though it is asked for once.
* **Reading part of a collection.** `first`, `take`, `any?`, `none?`, `empty?`, and `one?` request pages no larger than they need, and answer from the pages the cursor already holds. A cursor has no `size`, so `each_slice` and `lazy` do not page a whole collection to measure it; `count` reads every page and `published_count` reads the number the API publishes without reading any.
* **Serialization.** Resources, problems, trends, the usage, the rules a post matched, and pages answer `as_json` and `to_json` with their attributes, as plain data, so nothing carries a client or its credentials into a cache or a log. A page answers in the shape of the response it came from, its resources as the `data`, beside its `meta` and, when there are any, its problems as the `errors`, so the `from_response` of its resource class builds it again, though with stubs for the objects the response included. A cursor raises `X::UnsupportedOperation` from both, and `TypeError` from `Marshal.dump` and `YAML.dump`, since serializing it would read, and bill, every page of its collection; serialize `cursor.first(10)`, or `cursor.to_a` for all of it. `Marshal` writes each of the others as plain data led by the number of its format, so that every release of 1.x reads what another wrote, a later one adding only what an earlier one ignores, and raises `X::UnsupportedFormat` for a format it does not read, and each of them writes the same plain data as YAML, each part under its name, since YAML would otherwise write every instance variable, the client among them, and read back unfrozen what was frozen. A resource carries its attributes, whether it is hydrated, which it is read back as only if the query of its request asks for every field and expansion of the release that reads it, and of the response it came from, the included objects it refers to, and those they refer to in turn, the problems about any of them, and the query; a page carries its resources, metadata, and problems, and what the resources of one response refer to once, so a reference they shared is shared again; and each is frozen when it is read back. What it reads back resolves the references its response included, but has no client, so a `hydrate` that would make a request, a collection, or an action of it raises `X::MissingClient`, an `X::Resources::Error`.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config. It uses the `x-core` in this repository, whose errors and problems it raises and reports, and does not load `x-uploads`:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
