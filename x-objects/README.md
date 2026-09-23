# x-objects

The object layer of the [`x` gem](https://github.com/sferik/x-ruby): immutable, thread-safe resource classes for the [X API](https://developer.x.com) with identity, references, hydration, cached pagination, and parallel batch lookups.

It makes no HTTP requests itself: it asks a client to make them. Its one runtime dependency is [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core), for `X::Error`, the base class of every error the X gems raise.

Most applications should install [`x`](https://rubygems.org/gems/x), which wires this gem to the HTTP client from [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

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

`from_response` builds a resource from a parsed response, or an array of them when its data is a list. `X::Client` from `x-core` calls it when a resource class is the `object_class` of a request, passing the parsed body and itself:

```ruby
user = client.get("users/by/username/sferik", object_class: X::User)
```

An object built this way is not hydrated, because the request may have asked for only some fields, so `hydrate` fetches the full resource. The lookups, batch lookups, and cursors in this gem request every field, so what they return is already hydrated, unless they are given a parameter that overrides a default field or expansion parameter, such as `"user.fields": "name"`: what they return then is not hydrated either, so `hydrate` fetches the rest.

## How it works

* **Immutability.** Resources, pages, and cursors are frozen. Their attributes are deep-frozen copies of the response.
* **Identity.** `==`, `eql?`, and `hash` compare class and ID.
* **Identity map.** Each response gets one map. A reference resolves to the included object when the response expanded it, or to a stub otherwise, and every reference to the same resource in that response is the same object.
* **Hydration.** `hydrate` fetches the full resource once per object, under a lock, and memoizes it. `refresh` replaces the memoized value.
* **Cursors.** Pages are fetched lazily under a lock and cached, so concurrent iteration fetches each page once. `refresh` returns a cursor with an empty cache. `prefetch` returns a cursor that fetches the next page in a background thread.
* **Parallelism.** `find_all` splits IDs into batches of 100 and fetches the batches on up to 8 threads, preserving order.
* **Reading part of a collection.** `first`, `take`, `any?`, `none?`, `empty?`, and `one?` request pages no larger than they need, and answer from the pages the cursor already holds. A cursor has no `size`, so `each_slice` and `lazy` do not page a whole collection to measure it; `count` reads every page and `published_count` reads the number the API publishes without reading any.
* **Serialization.** Resources, problems, the usage, pages, and cursors answer `as_json` and `to_json` with their attributes, so nothing carries a client or its credentials into a cache or a log. `Marshal` carries a resource's attributes alone, and what it reads back has no client and cannot hydrate. Serializing a cursor pages the whole collection.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config. It uses the `x-core` in this repository, whose errors and problems it raises and reports, and does not load `x-uploader`:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
