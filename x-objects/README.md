# x-objects

The object layer of the [`x` gem](https://github.com/sferik/x-ruby): immutable, thread-safe resource classes for the [X API](https://developer.x.com) with identity, references, hydration, cached pagination, and parallel batch lookups.

It makes no HTTP requests itself: it asks a client to make them. Its one runtime dependency is [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core), for `X::Error`, the base class of every error the X gems raise.

Most applications should install [`x`](https://rubygems.org/gems/x), which wires this gem to the HTTP client from [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

## Installation

`x-objects` requires Ruby 3.4 or later.

    bundle add x-objects

## Resources

| Class | References | Collections | Class collections |
| --- | --- | --- | --- |
| `X::User` | `pinned_post`, `most_recent_post` | `followers`, `following`, `blocking`, `muting`, `posts`, `home_timeline`, `mentions`, `liked_posts`, `bookmarks`, `owned_lists`, `list_memberships`, `followed_lists`, `pinned_lists` | `search` |
| `X::Post` | `author`, `in_reply_to_user`, `community`, `replied_to`, `quoted`, `reposted`, `references`, `media`, `polls`, `place` | `liked_by`, `reposted_by`, `reposts`, `quotes` | `search`, `search_all`, `reposts_of_me` |
| `X::List` | `owner` | `members`, `followers`, `posts` | |
| `X::DirectMessage` | `sender`, `participants`, `references`, `media` | | `all`, `with`, `in` |
| `X::Space` | `creator`, `hosts`, `speakers`, `invited_users` | `posts` | `search` |
| `X::Community` | | | `search` |
| `X::Media` | | | |
| `X::Poll`, `X::Place` | | | |

Every class but `X::Poll` and `X::Place`, which the API has no lookup for, is looked up with `find`, as in `X::Media.find("3_1880028106020515840", client:)`, which looks media up by its media key. A collection is an `X::Cursor`, read from a resource, as in `user.followers`, and a class collection is one read from the class with a client, as in `X::Post.search("ruby", client:)`.

`X::User.find` reads an Integer or a user as an identifier and a String as a username, so a handle of digits needs `X::User.find_by_username` (or `find_by_username!`, and `client.find_user_by_username`) to say which is meant.

The space endpoints take only app-only authentication, so `X::Space.find`, `find_all`, `search`, and `space.posts` make their requests with the client's app-only client when it has one. The bookmark endpoints take only OAuth 2.0 user context, which the gem cannot route around.

## The client contract

Any object that responds to `get`, `post`, `put`, and `delete` can be the client. Each method takes a path relative to the API base URL and keyword options, and returns the parsed JSON body. `post` and `put` also take the request body as an optional second argument: a Hash, which the client sends as JSON, as `X::Client` does, or a String the client sends as it is. The object layer always passes `array_class: Array, object_class: Hash`, so a client's own parsing defaults can't change what it receives. `X::Client` from `x-core` satisfies this contract.

Those two are the only keywords the object layer passes, but a release within 1.x may pass any other keyword `X::Client` takes for the same method, such as `params:` or `headers:`, so take the keywords with `**options`, as below, rather than name the two alone.

A client that also answers `app_only`, `authenticator`, `current_user_id`, `memoized`, or `memoize` is asked for them where they save a request, as `X::Client` is. `memoized(key)` reads, and `memoize(key, value)` keeps, a value under a Symbol key, such as `:x_objects_current_user_id`, for the authenticator the client holds; a client without them keeps the identifier of the authenticated user in its `@x_objects_current_user_id` instance variable, unless it is frozen. The object layer reads the errors of `x-core`, so a client raises them for a request that fails: `X::Unauthorized` or `X::Forbidden` for credentials the API refuses, which `follows?` reads as a client that knows no authenticated user, and scans instead, and `X::UnsupportedOperation` from an `app_only` that holds no credentials of the app, which the space, count, and usage endpoints read as a client that requests as itself, so an endpoint that takes app-only authentication alone, such as the count of the full archive, raises the `X::Forbidden` of the 403 Forbidden the API answers it with. Any other error ends the call it was raised in.

```ruby
require "x/objects"

class MyClient
  include X::Objects::API # adds find_user, find_user_by_username, find_users, current_user, find_post, find_posts, search, find_list, find_media, find_space, find_community, find_dm, follow, like, ...

  def get(path, **options) = ...
  def post(path, body = nil, **options) = ...
  def put(path, body = nil, **options) = ...
  def delete(path, **options) = ...
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

* **Immutability.** Resources, pages, and cursors are frozen. Their attributes are deep-frozen copies of the response.
* **Identity.** `==`, `eql?`, and `hash` compare class and ID.
* **Identity map.** Each response gets one map. A reference resolves to the included object when the response expanded it, or to a stub otherwise, and every reference to the same resource in that response is the same object.
* **Hydration.** `hydrate` fetches the full resource once per object, under a lock, and memoizes it. `refresh` replaces the memoized value.
* **Cursors.** Pages are fetched lazily under a lock and cached, so concurrent iteration fetches each page once. `refresh` returns a cursor with an empty cache. `prefetch` returns a cursor that fetches the next page in a background thread.
* **Parallelism.** `find_all` splits IDs into batches of 100 and fetches the batches on up to 8 threads, preserving order.
* **Reading part of a collection.** `first`, `take`, `any?`, `none?`, `empty?`, and `one?` request pages no larger than they need, and answer from the pages the cursor already holds. A cursor has no `size`, so `each_slice` and `lazy` do not page a whole collection to measure it; `count` reads every page and `published_count` reads the number the API publishes without reading any.
* **Serialization.** Resources, problems, trends, the usage, the rules a post matched, and pages answer `as_json` and `to_json` with their attributes, as plain data, so nothing carries a client or its credentials into a cache or a log. A page answers in the shape of the response it came from, its resources as the `data`, beside its `meta` and, when there are any, its problems as the `errors`, so the `from_response` of its resource class builds it again, though with stubs for the objects the response included. A cursor raises `X::UnsupportedOperation` from both, and `TypeError` from `Marshal.dump` and `YAML.dump`, since serializing it would read, and bill, every page of its collection; serialize `cursor.first(10)`, or `cursor.to_a` for all of it. `Marshal` writes each of the others as plain data led by the number of its format, so that a later 1.x release reads what an earlier one wrote, and raises `X::UnsupportedMarshalFormat` for a format it does not read, and a resource and a page write the same plain data as YAML, each part under its name, since YAML would otherwise write every instance variable, the client among them. A resource carries its attributes, whether it is hydrated, which it is read back as only if the query of its request asks for every field and expansion of the release that reads it, and of the response it came from, the included objects it refers to, and those they refer to in turn, the problems about any of them, and the query; a page carries its resources, metadata, and problems, and what the resources of one response refer to once, so a reference they shared is shared again; and each is frozen when it is read back. What it reads back resolves the references its response included, but has no client, so a `hydrate` that would make a request, a collection, or an action of it raises `X::MissingClient`, an `X::Objects::Error`.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config. It uses the `x-core` in this repository, whose errors and problems it raises and reports, and does not load `x-uploader`:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
