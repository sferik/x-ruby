# x-objects

The object layer of the [`x` gem](https://github.com/sferik/x-ruby): immutable, thread-safe resource classes for the [X API](https://developer.x.com) with identity, references, hydration, cached pagination, and parallel batch lookups.

It has no runtime dependencies and makes no HTTP requests itself. It asks a client to make them.

Most applications should install [`x`](https://rubygems.org/gems/x), which wires this gem to the HTTP client from [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

## Resources

| Class | References | Collections |
| --- | --- | --- |
| `X::User` | `pinned_post`, `most_recent_post` | `followers`, `following`, `posts`, `mentions`, `liked_posts`, `bookmarks`, `owned_lists`, `list_memberships`, `followed_lists` |
| `X::Post` | `author`, `in_reply_to_user`, `community`, `replied_to`, `quoted`, `reposted`, `references`, `media`, `polls`, `place` | `liked_by`, `reposted_by`, `reposts`, `quotes` |
| `X::List` | `owner` | `members`, `followers`, `posts` |
| `X::DirectMessage` | `sender`, `participants`, `references`, `media` | |
| `X::Space` | `creator`, `hosts`, `speakers`, `invited_users` | `posts` |
| `X::Community` | | |
| `X::Media`, `X::Poll`, `X::Place` | | |

## The client contract

Any object that responds to `get`, `post`, `put`, and `delete` can be the client. Each method takes a path relative to the API base URL and keyword options, and returns the parsed JSON body. `post` and `put` also take the request body, a JSON String, as an optional second argument. The object layer always passes `array_class: Array, object_class: Hash`, so a client's own parsing defaults can't change what it receives. `X::Client` from `x-core` satisfies this contract.

```ruby
require "x/objects"

class MyClient
  include X::Objects::API # adds find_user, find_users, current_user, find_post, find_posts, search, find_list, find_space, follow, like, ...

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

An object built this way is not hydrated, because the request may have asked for only some fields, so `hydrate` fetches the full resource. The lookups, batch lookups, and cursors in this gem request every field, so what they return is already hydrated.

## How it works

* **Immutability.** Resources, pages, and cursors are frozen. Their attributes are deep-frozen copies of the response.
* **Identity.** `==`, `eql?`, and `hash` compare class and ID.
* **Identity map.** Each response gets one map. A reference resolves to the included object when the response expanded it, or to a stub otherwise, and every reference to the same resource in that response is the same object.
* **Hydration.** `hydrate` fetches the full resource once per object, under a lock, and memoizes it. `refresh` replaces the memoized value.
* **Cursors.** Pages are fetched lazily under a lock and cached, so concurrent iteration fetches each page once. `refresh` returns a cursor with an empty cache. `prefetch` returns a cursor that fetches the next page in a background thread.
* **Parallelism.** `find_all` splits IDs into batches of 100 and fetches the batches on up to 8 threads, preserving order.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config, and does not load the other gems in this repository:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
