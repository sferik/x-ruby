# Changelog

All notable changes to `x-resources` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`x-resources` is released in lockstep with the other gems of the [x-ruby](https://github.com/sferik/x-ruby) repository, at one version across `x-core`, `x-uploads`, `x-streams`, `x-resources`, and `x`. This file holds the changes to the object layer; [the changelog of the repository](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) holds the changes to every gem.

## [1.0.0] - 2026-09-18

The first release of `x-resources`, which 1.0.0 split out of the `x` gem. `x` 0.19, the last release before the split, had no object layer, so every entry below is new; see [UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) for the changes that code written for 0.19 needs. It requires Ruby 3.4 or later.

### Added
* Add `X::Resources.gem_version`, which returns `VERSION` as a `Gem::Version`
* Split `x` into gems released in lockstep: `x-core`, `x-uploads`, `x-streams`, `x-resources`, and the `x` meta-gem
  * `x-core` is the HTTP client and declares `X::Error`, the base of every error the gems raise
  * `x-resources` makes no request of its own; it asks the client it is given to make them
  * Public classes are named directly under `X`, whichever gem declares them
  * `x` depends on exactly its own version of the other four; `x-uploads`, `x-streams`, and `x-resources` each depend on `x-core` with `>= 1.0.0, < 2`
* Add `X::Resources::Error`, to rescue the failures of the object layer alone
  * `X::MissingResource`, `X::UnreadableResponse`, `X::MissingClient`, and `X::PageLimitReached` descend from it
  * `X::InvalidAttribute` descends from `X::UnreadableResponse`
* Add immutable, thread-safe resource classes that descend from `X::Resource`
  * `X::User`, `X::Post` (aliased `X::Tweet`), `X::List`, `X::DirectMessage`, `X::Space`, `X::Media`, and `X::Poll`
  * `X::Place`, and `X::Community`, found with `find_community(!)` and `search_communities`, and read as `post.community`
  * Post in a community with the `community:` of `create_post`
  * Lookups, cursors' `to_a`, and the collections a resource holds are frozen Arrays; copy one to change it
  * A list the response omits, such as `post.urls`, reads as an empty Array; `user.connection_status` reads nil
  * Text reads as the API sends it, so `post.text` and `direct_message.text` hold `&amp;`, `&lt;`, and `&gt;` throughout 1.x
  * Nested data, such as `post.entities` and `post.public_metrics`, reads as frozen Hashes keyed by String throughout 1.x
  * Nested data the API sends as anything but an object, or a list of them, raises `X::InvalidAttribute`
* Compare resources by class and ID with `==`, `eql?`, and `hash`
* Resolve references such as `post.author` to included objects or ID stubs, sharing one object per resource
* Add `hydrate`, which fetches and memoizes the full resource, and `refresh`, which fetches it again
  * A resource without a client, such as one read back by `Marshal`, raises `X::MissingClient` from any request
  * A lookup whose parameters leave out default fields or expansions returns resources that are not hydrated
  * `FIELDS` and `EXPANSIONS` may grow in a minor release; add to `default_params` rather than list every value
* Add `X::Cursor`, an `Enumerable` that fetches pages lazily, caches them, and offers `refresh` and `prefetch`
  * A page a prefetch failed to fetch raises the prefetch's error once it is reached, rather than be requested again
  * `first`, `take`, `any?`, `none?`, `one?`, and `empty?` answer from the pages already held, and keep what they read
  * Without a block or pattern, `any?`, `none?`, and `empty?` request one resource and `one?` two, not a full page
  * That is raised to the endpoint's minimum page size: 5 for a user's posts, mentions, and liked posts; 10 for post and community searches and quotes
  * `first` and `take` request no larger a page than needed; a count that does not convert raises `TypeError`
  * A page that names a token already read as its next raises `X::UnreadableResponse`, rather than page forever
  * `page` takes an Integer index from zero; another type raises `TypeError`, a negative index `ArgumentError`
* Add `X::Cursor#each_page`, which yields each page as an `X::Page`
  * A page holds `items`, `meta`, `result_count`, `next_token`, `previous_token`, and `problems`, and reads its items as an Array does
  * `X::Page.new` takes an Array of resources and `meta:` and `problems:`; other problems raise `ArgumentError`
  * Pages are equal when they hold the same resources, in order, meta, and problems
* Add `X::Cursor#published_count`, the number the API publishes for a collection, without paging it
  * For a user's followers, followed users, and list memberships, and a list's members and followers
  * It is nil for any other collection; `count` pages through the collection, as `Enumerable` does
* Add `X::Cursor#ids`, which requests identifiers alone, and `stubs`, which scans a collection as stubs
* Read the collections of a resource as cursors
  * A user's `followers`, `following`, `affiliates`, `posts`, `mentions`, `liked_posts`, and `owned_lists`
  * A user's `list_memberships`, `followed_lists`, `pinned_lists`, `home_timeline`, `blocking`, and `muting`
  * A list's `members`, `followers`, and `posts`, and a post's `quotes`
  * A space's `posts`, and its `buyers`, which the API reads for OAuth 2.0 user context alone
* Add `X::Post#reply?`, `quote?`, and `repost?`, and read the post referred to with `replied_to`, `quoted`, `reposted`
* Add `X::Post#liked_by`, `reposted_by`, and `reposts`, and `references`, the posts a post or direct message refers to
* Look users and posts up by ID in parallel batches of 100 with `X::User.find_all` and `X::Post.find_all`
  * They return one resource per ID found, in the order asked, so an ID given twice comes back twice
  * Once a batch fails, or the waiting thread is interrupted, no batch not yet begun is sent
* Look many resources up at once with `find_all_users`, `find_all_posts`, `find_all_spaces`, and `find_all_media`
  * `find_all_users` takes a mix of IDs and usernames, batching each kind separately
  * `find_all_users_by_username` takes usernames alone, even ones that are all digits
* Set how many batches a lookup requests at once with `concurrency:`, 4 by default
  * Taken by `find_all`, `find_all_by_username`, `hydrate_all`, `find_all_by_creator`, and their client methods
  * Anything but an Integer of at least 1 raises `ArgumentError`
* Hydrate many resources in parallel batches with `hydrate_all` on `X::User`, `X::Post`, `X::Space`, and `X::Media`
  * It drops nil and resources not found, and looks up none that is already hydrated
  * It stores what it finds in each resource given, unless the parameters leave out default fields or expansions
  * A resource of another class raises `ArgumentError` before a request
* Hydrate the stubs of a page of `stubs`, or of a cursor that requests identifiers alone, together, in batch lookups of up to 100
  * Lists, communities, and direct messages, which the API looks up one at a time, hydrate one at a time
  * A reference a page did not include, such as the `author` of a post, hydrates one at a time; `hydrate_all` batches any
* Add object methods to `X::Client`, with `find_tweet` aliases for the finders
  * `find_user`, `find_post`, `find_list`, `find_space`, `search_posts`, and `search_all_posts`
  * `create_post`, `delete_post`, `direct_messages`, and `create_direct_message`
  * `follow`, `unfollow`, `like`, `unlike`, `repost`, and `unrepost`
  * `follow` returns true once it asks to follow a protected user; `repost` returns true once the user has reposted
* Add `block`, `unblock`, `mute`, `unmute`, `bookmark`, and `unbookmark` to `X::Client`
* Add `follow_list`, `unfollow_list`, `pin_list`, and `unpin_list` to `X::Client`
* Read the authenticated user's posts that others reposted with `X::Post.reposts_of_me` and `client.reposts_of_me`
  * Both are aliased as `retweets_of_me`
* Read the authenticated user with `client.current_user` and `current_user!`, or `X::User.current` and `current!`
  * `current_user` returns nil, yielding the problems the API reported; `current_user!` raises `X::MissingResource`
  * `current_user_id` keeps the ID per credentials, even on a frozen `X::Client`; a frozen client without `memoize` looks it up each time
  * With OAuth 1.0a, `current_user_id` reads the ID from the access token, without a request
* Look a user up by ID when given an Integer and by username when given a String
  * Say which with `X::User.find_by_id(!)`, `find_all_by_id`, `find_by_username(!)`, and `find_all_by_username`
  * On the client: `find_user_by_id(!)`, `find_all_users_by_id`, `find_user_by_username(!)`, `find_all_users_by_username`
  * The `by_id` methods look a String of digits up as an ID, as read from a response or an environment variable
  * Elsewhere, such as `follow`, `from_id`, or `find_post`, an ID that is not a number raises `ArgumentError`
  * So does a resource of another class, as in `client.like(user)`, or another object that answers `id`
* Accept a username with a leading `@` in `find_user`, `find_all_users`, and `X::User.find_all_by_username`
* Validate a username or a non-numeric ID before building a path from it, raising `ArgumentError` without a request
  * Such as `find_user("")`, `find_user("../tweets/20")`, `find_user("sferik?expansions=x")`, or `find_user("bad name")`
* Raise `X::MissingResource` from `current_user!` and every `find…!` method when a lookup finds nothing
  * Its message names what was looked up, as in "Could not find X::User @sferik"
  * It is not `X::NotFound`: a missing resource gives nil or `X::MissingResource` whether X answers 200 OK with no data or a 404 that reports the resource as not found
  * The `X::NotFound` of such a 404 is its `cause`; any other 404, such as one from a client pointed at the wrong host or API version, or one to `current_user` or a `find_all…`, raises `X::NotFound`
  * Data that holds no identifier counts as not found too, rather than raising `X::InvalidAttribute`
* Refer to a resource without a request with `X::User.from_id` and its equivalents, and tell stubs apart with `stub?`
  * `X::Resource` itself keeps `new`, `from_id`, and `from_response` private
* Pass a resource class, such as `X::User`, as the `object_class` of any request to build objects from the response
  * A list builds an `X::Page`, which holds the response's `meta` and problems, and is empty when there is no `data`
  * Any `object_class` that responds to `from_response` is passed the parsed body and `client:`
  * A `from_response` of your own must take unknown keywords with `**`, since a 1.x release may pass more
* Include the object methods in a class of your own with `X::Resources::API`
  * The class is the client of each request, and answers `get`, `post`, `put`, and `delete` (`X::Resources::_Client`)
  * Those methods must take unknown keywords, since a 1.x release may pass any keyword `X::Client` takes
  * `X::Resources` names `API`, `Error`, and `VERSION` alone; the modules and helpers behind them are private
  * Constants a resource class shares are private, so `X::Post::REPLIED_TO` raises `NameError`
  * The signatures the gem ships declare its public interface alone
* Search users with `X::User.search` and `client.search_users`
* Search live and scheduled spaces with `X::Space.search` and `client.search_spaces`
* Request the largest page each search allows
  * 500 posts from `search_all_posts`, or 100 when the request asks for context annotations, as the default fields do
  * 1,000 users from `search_users`
* Check `list.member?` and `user.follows?` without fetching every page
  * `member?` scans the smaller of a public list's members and the user's memberships; a private list scans members
  * `follows?` looks up `X::User#connection_status` once when either user is the authenticated user
  * A 401 or 403 to the lookup of the authenticated user falls back to a scan; any other failure, such as a rate limit, raises
  * `max_pages:` limits the pages a scan reads, raising `X::PageLimitReached` if the API names another
  * `max_pages:` defaults to nil, no limit; anything but an Integer of at least 1 or nil raises `ArgumentError`
* Count the posts that match a query with `X::Post.count`, `count_all`, `count_by_period`, and `count_all_by_period`
  * On the client: `count_posts`, `count_all_posts`, `count_posts_by_period`, and `count_all_posts_by_period`
  * Those have tweet-named aliases, and pass `max_pages:` through
  * The by-period counts are in time order, keyed by the `Range` of `Time` each period spans
  * A client that signs with OAuth 1.0a counts with a copy that authenticates as the app
  * An OAuth 2.0 user client without app credentials counts as the user; the full archive refuses it with `X::Forbidden`
  * Every count takes `max_pages:`, raising `X::PageLimitReached` past it, as `follows?` does
  * A count by period that is not a String of digits or a non-negative Integer raises `X::InvalidAttribute`
* Report how many posts the app's project has read with `X::PostUsage.current` and `client.post_usage`
  * It holds the monthly cap, the day it resets on, and usage by day and by app, each count an Integer
  * They return nil, yielding the response's problems to a block, when it holds no usage
  * `X::PostUsage.current!` and `client.post_usage!` raise `X::MissingResource` instead
  * An OAuth 2.0 user client without app credentials requests as the user, which the API refuses with `X::Forbidden`
* Report the partial errors of a successful response as `X::Problem` objects, which `x-core` declares
  * Read them with `problems` on a resource or a page, a block given to a finder, or `X::MissingResource#problems`
  * A resource holds the problems about it, or a resource it refers to directly, and those that name no resource
* Look up a direct message with `find_direct_message`, and the conversation with a user with `direct_messages_with`
* Delete a direct message with `X::DirectMessage.delete`, `message.delete`, and `client.delete_direct_message`
* Add `X::DirectMessage#peer(user)`, the other participant of a one-to-one conversation as the user given sees it
  * It is nil for a group conversation, as `group?` tells, and for a user not in the conversation
* Start a group conversation with `X::DirectMessage.create_group` and `client.create_group_direct_message`
* Send to and read any conversation with `X::DirectMessage.create_in` and `X::DirectMessage.in`
  * On the client: `create_direct_message_in` and `direct_messages_in`
  * Each takes a message of the conversation or its identifier
* Add `dm` aliases for the client methods named for direct messages
  * `find_dm`, `find_dm!`, `dms`, `dms_with`, `create_dm`, `delete_dm`, `create_group_dm`, `create_dm_in`, and `dms_in`
* Attach uploaded media to a direct message with `media_ids:`, as `create_post` takes it
  * Passing both `media_ids:` and `attachments:` raises `ArgumentError`
  * An empty `media_ids:` attaches nothing to a post or a message, as nil does
* Post media without text, and send a direct message of attachments alone
  * Without text, no `text` field is sent; a call with neither text nor any other field raises `ArgumentError`
* Build a new post's `reply` and `media` from the `reply_to:` and `media_ids:` of `create_post`
  * Any other field of a `reply:` or `media:` passed beside them is kept
  * A field passed with a String key, such as `"reply"` or `"attachments"`, is read as its Symbol, so it is sent once
  * `media_ids:` takes a single value as well as an Array
* Accept what an upload returns, media, or a media key in the `media_ids:` of `create_post`
  * An ID is sent only as 1 to 19 digits; anything else, such as a Hash without an `"id"`, raises `ArgumentError`
* Quote a post with the `quote:` of `create_post` and `X::Post.create`
* Raise `X::MissingResource`, holding the response's problems, when a request that creates a resource is answered without it
  * From `X::Post.create`, `X::List.create`, `X::DirectMessage.create`, `create_group`, `create_in`, and their client methods
  * So `create_post`, `create_list`, `create_dm`, and the rest never return nil
  * A response whose data names no identifier raises it too
* Hide a reply to the authenticated user's post, and show it again, with `hide_reply` and `unhide_reply`
  * On `X::Post` instances, on the `X::Post` class, and on the client
* Manage lists with `X::List.create`, `X::List.update`, `X::List.delete`, `list.update`, and `list.delete`
  * Add and remove members with `list.add_member` and `list.remove_member`
  * On the client: `create_list`, `update_list`, `delete_list`, `add_list_member`, and `remove_list_member`
  * An update with no field to change raises `ArgumentError` before a request
* Add `X::User#bookmark_folders`, a cursor of `X::BookmarkFolder`, and read a folder's posts with `bookmarks(folder:)`
  * Hydrating or refreshing a folder that is not hydrated raises `X::UnsupportedOperation`, since the API has no lookup
* Look up the spaces of many creators with `X::Space.find_all_by_creator` and `client.find_all_spaces_by_creator`
  * They take users or their IDs, 100 at a time in parallel batches, and yield each problem the API reports
* Look up, search, and read the posts of spaces whatever the client authenticates with
  * A client that signs with OAuth 1.0a makes those requests with its app-only client
  * An OAuth 2.0 user client without app credentials makes them itself, and the spaces and posts returned act as that user; one that holds app credentials makes them with its app-only client
* Add `X::Space#topics`, each an `X::Topic` with a `name` and a `description`
* Look up media by media key with `X::Media.find`, `find!`, and `find_all`
  * On the client: `find_media`, `find_media!`, and `find_all_media`
  * They take a media key, media, or what an upload returned; the numeric media ID raises `ArgumentError`
  * `client.find_media(uploaded)` reads what an upload became, with its URL and variants
* Add `X::Media#media_id`, the Integer its media key names, as `X::UploadedMedia#media_id` reads it
  * `X::Media#id` is the media key, which the API looks media up by
* Read the trends of a place with `X::Trend.at` and `client.trends`, given its WOEID, such as 1 for the world
  * A WOEID that is not a number raises `ArgumentError` before a request
  * It returns up to 50 trends unless given `max_trends:`, each with a `name` and a `post_count`
  * A client that signs with OAuth 1.0a, which the endpoint refuses, requests as the app
* Read the trends X picks for the authenticated user with `X::PersonalizedTrend.all` and `client.personalized_trends`
  * Read `name`, `category`, and `post_count_text` and `trending_since_text`, the text X shows
  * Neither trends endpoint has pages, so each returns a frozen Array; trends are equal when their attributes are
* Read the full text of a long post, over 280 characters, with `X::Post#text`, from its `note_post`
  * `entities` and `urls` read the note's entities alone, so they lie where `text` holds them
* Add `X::Post#urls` and `expanded_text`, the text with each shortened link replaced by the URL it stands for, in one pass
  * `expanded_text` HTML-escapes each URL it puts in, so the whole text reads escaped, as `text` does
* Add `X::Post#matching_rules`, the filtered stream rules a post matched, each an `X::MatchingRule`
  * A rule reads the `id` the API gave it, as an Integer, and its `tag`; building one whose `id` is not digits raises `ArgumentError`, and reading one from a post raises `X::InvalidAttribute`
  * A post that did not come from the filtered stream matched none
* Add `X::DirectMessage#from?`, `X::Post#coordinates`, and `permalink` and `uri`, the x.com address of a resource
  * `permalink` and `uri` are on posts, users, lists, and communities
* Read more fields, which the lookups request
  * `X::User#profile_banner_url`, `parody?`, `identity_verified?`, `subscription_type`, `verified_followers_count`
  * `X::User#subscriber_count` and `media_count`
  * `X::Post#display_text_range`, an exclusive `Range`, nil when absent, and `scopes`, `card_uri`, `article`, `article_title`, `media_metadata`, `paid_partnership?`
  * `X::DirectMessage#entities`
  * `X::User#affiliation`, `affiliated_with_ids`, and `affiliated_with`; a user included in another resource has none
  * Fields only an author, an advertiser, or a program may read are not requested, since asking fails for others
* Add `X::User#receives_your_dm?`, `subscribes_to_you?`, and `subscription`; the predicates are false, and `subscription` nil, unless `user.fields` names them
* Add `X::Post#media_source_posts`, aliased `media_source_tweets`, the posts its attached media was first posted with
  * Resolved from the `attachments.media_source_tweet` expansion, which lookups request
* Read the API's `is_` flags as `X::User#identity_verified` and `X::Space#ticketed`, beside their `?` predicates
* Match resources against `case/in` patterns by every attribute they declare, as in `post in {like_count: 100..}`
  * Tweet-named aliases match too, as in `user in {pinned_tweet_id: Integer}`
  * `X::Trend`, `X::PersonalizedTrend`, and `X::PostUsage` match by their readers, as in `trend in {post_count: 10..}`
* Write resources and value objects as JSON with `as_json` and `to_json`, never with the client's credentials
  * On `X::Resource`, `X::Problem`, `X::Trend`, `X::PersonalizedTrend`, `X::PostUsage`, `X::MatchingRule`, and `X::Page`
  * A page writes the shape of its response, which the `from_response` of its resource class reads back
* Marshal and YAML-dump them in a format every 1.x release reads
  * An unknown format raises `X::UnsupportedFormat`, which `x-core` declares
  * A resource keeps its attributes, the included objects it refers to, and its query, but not its client
* Raise from a cursor's `as_json`, `to_json`, and `to_h`, and from `Marshal.dump` and `YAML.dump` of one
  * They raise `X::UnsupportedOperation` and `TypeError`, rather than read every page; serialize `first(n)` or `to_a`
* Name the interface after posts rather than tweets, as in `post_count`, `pinned_post_id`, and `repost_count`
  * Tweet-named methods, such as `create_tweet`, `tweets`, `quote_tweets`, and `retweet_count`, remain as aliases
  * A response that uses tweet names, as a stream does, is read where the post-named field is missing
* Request fields and expansions by the names the X API documentation gives, such as `post.fields` and `referenced_posts`
  * The authors of referenced posts are not expanded, since the API reference names no expansion for them
* Leave out the `edit_history_post_ids` and `entities.mentions.username` expansions, whose includes nothing reads
* Read the IDs of users, posts, lists, direct messages, communities, and polls, and references to them, as Integers
  * `X::Problem#resource_id` and `value` are Strings, so match a problem to a resource with `problem.about?(user)`
  * IDs of spaces, places, and media, media keys, `dm_conversation_id`, and usernames are Strings
  * A space or place ID is word characters alone; a `dm_conversation_id` that is not digits, or two numbers joined by a hyphen, raises `X::InvalidAttribute`
* Raise `X::UnsupportedOperation`, which `x-core` declares, for anything the API offers no way to do
  * Such as hydrating or refreshing an `X::Poll` or an `X::Place` that is not hydrated
  * A lookup the API lacks is not defined: `X::Poll` and `X::Place` answer no finder
  * `X::List`, `X::Community`, and `X::DirectMessage` answer `find` and `find!`, but not `find_all` or `hydrate_all`
* Validate the attributes of a resource, a page, a trend, or the usage when it is built, raising `ArgumentError`
  * As in `X::User.new({"id" => "abc"})`, `X::Trend.new(nil)`, or a page of items that are not resources
* Raise `X::InvalidAttribute` where a value of a response cannot be read as the API documents it
  * Such as a timestamp that is not ISO 8601, a `public_metrics` that is a String, or a link whose `url` is not a String
  * A count reads a String of digits as a number, and raises for a negative, signed, or fractional value
  * A flag, such as `protected`, reads true, false, or nil, and raises for anything else
  * Its cause is the `ArgumentError` that refused the value
* Type-check collections: `X::Cursor` and `X::Page` are generic in their signatures
* Ship a `sig/manifest.yaml` naming `uri` and `json`, so `rbs collection` loads them for code that depends on the gem
* Ship this changelog with the gem, linked from the `changelog_uri` of its gemspec
* Ship a `.yardopts` with the gem, so its documentation on rubydoc.info leaves out the private API

[1.0.0]: https://github.com/sferik/x-ruby/releases/tag/v1.0.0
