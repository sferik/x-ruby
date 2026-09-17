# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-09-16

See [UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) for the changes that code written for 0.19 needs.

### Added
* Split the gem into gems released in lockstep: `x-core` (the HTTP client), `x-uploader` (media, profile image, and banner uploads), `x-objects` (resource objects), and `x` (a meta-gem that depends on all three and mixes the object methods into `X::Client`)
* Add immutable, thread-safe resource classes: `X::User`, `X::Post` (aliased as `X::Tweet`), `X::List`, `X::DirectMessage`, `X::Space`, `X::Media`, `X::Poll`, and `X::Place`
* Compare resources by class and ID with `==`, `eql?`, and `hash`, so the same resource fetched in different requests is equal
* Resolve references such as `post.author` and `post.replied_to` to included objects or ID stubs, sharing one object per resource within a response
* Add `hydrate`, which fetches and memoizes the full resource, and `refresh`, which fetches it again
* Add `X::Cursor`, an `Enumerable` collection that requests the maximum page size, fetches pages lazily, caches them, and offers `refresh` and `prefetch`
* Check a collection without paging it: `X::Cursor#any?`, `X::Cursor#none?`, and `X::Cursor#one?` request one or two resources, rather than a full page, when they are given no block or pattern
* Count a collection without paging it: `X::Cursor#count` and `X::Cursor#size` read the number the API publishes for a user's followers, followed users, and list memberships, and for a list's members and followers, looking up a stub, such as the user of `X::User.from_id(id).followers`, to read the number, and falling back to a scan for a collection the API publishes no number for
* Look up users and posts by ID in parallel batches of 100 with `X::User.find_all` and `X::Post.find_all`, asking for each ID once
* Add `find_user`, `find_users`, `current_user`, `find_post`, `find_posts`, `search_posts`, `search_all_posts`, `create_post`, `delete_post`, `find_list`, `find_space`, `direct_messages`, `create_direct_message`, `follow`, `unfollow`, `like`, `unlike`, `repost`, and `unrepost` to `X::Client`; the finders have `find_tweet` aliases and `search` is short for `search_posts`, and `follow` reports true once it has asked to follow a protected user, whose acceptance is pending
* Pass a resource class, such as `X::User`, as the `object_class` of any request to build objects from the response, or an array of them from a list; a client passes the parsed body and itself to any `object_class` that responds to `from_response`, and the objects it builds hydrate to the full resource, since a request may have asked for only some fields
* Pass query parameters to `get`, `post`, `put`, `delete`, and `stream` as `params:`, which drops nil values and joins arrays with commas, so callers no longer build query strings by hand
* Encode a Hash passed as the body of `post` or `put` as JSON, and encode `form:` fields as a form body with the matching content type
* Authenticate as an app when a client is given an `api_key` and `api_key_secret` without access tokens: `X::AppOnlyAuthenticator` fetches a bearer token with the client credentials grant on the first request and keeps it
* Page an endpoint that names its page token differently with the `token_param:` of `X::Cursor`, and search users with `X::User.search` and `client.search_users`, which page with `next_token`
* Request nothing but identifiers from a cursor with `ids`, as in `user.followers.ids`
* Refer to a resource without a request with `X::User.from_id` and its equivalents, and tell such stubs and unexpanded references apart from expanded ones with `stub?`
* Add `home_timeline`, `blocking`, and `muting` cursors to `X::User`, and read the authenticated user's posts that others have reposted with `reposts_of_me` on the client and `X::Post.reposts_of_me`
* Add `block`, `unblock`, `mute`, and `unmute` to the actions of `X::User` and `X::Client`
* Add `X::List.create`, `X::List.update`, `X::List.delete`, `list.add_member`, `list.remove_member`, `list.update`, and `list.delete`, with `create_list`, `update_list`, and `delete_list` on the client
* Add `X::DirectMessage.delete`, `message.delete`, and `delete_direct_message` on the client, and `message.peer`, the other participant of a one-to-one conversation, which is nil for a group conversation, as `message.group?` tells
* Make `current_user`, the memoized authenticated user, public on the client, in place of `me`, which made a request every call
* Look up a mix of identifiers and usernames with `find_users`, which batches each kind separately instead of treating everything as a username, and returns the users in the order they were asked for
* Look up a direct message with `find_direct_message`, many spaces with `find_spaces`, and the conversation with a user with `direct_messages_with`
* Add `X::Community`, looked up with `find_community` and `find_community!`, searched with `search_communities`, referred to by `post.community`, and posted in with the `community:` of `create_post`
* Shorten every client method named for direct messages with a `dm` alias: `find_dm`, `find_dm!`, `dms`, `dms_with`, `create_dm`, and `delete_dm`
* Build the `reply` and `media` fields of a new post from the `reply_to:` and `media_ids:` of `create_post`
* Describe uploaded media with alt text, through the `alt_text:` of `X::Uploader::Media.upload` or `X::Uploader::Metadata.add_alt_text`, and attach uploaded subtitles to a video with `X::Uploader::Metadata.add_subtitles`
* Upload a GIF with a single frame as an image, since X fails to process it as a GIF, telling a still GIF from an animated one with `X::Uploader::Gif.animated?`
* Request a page no larger than needed from `X::Cursor#first` and `X::Cursor#take`, raised to the endpoint's minimum, since the API bills each resource returned, and ask each page after the first for no more than the pages before it left
* Check `list.member?` by scanning the smaller of a public list's members and the lists the user is on, comparing `member_count` with `listed_count`; a private list still scans its members
* Check `follows?` with one lookup of `connection_status` when either user is the authenticated user, instead of scanning every user followed, and read that field with `X::User#connection_status`
* Infer the media category of an upload from the file extension, upload a video in chunks, and wait for a video or an animated GIF to be processed, so `X::Uploader::Media.upload("cat.mp4", client:)` handles any file, taking the `media_type:`, `chunk_size_mb:`, and `concurrency:` of a chunked upload and raising `ArgumentError` for any other keyword
* Take the file path, content, or media as the positional argument of the `X::Uploader::Media`, `X::Uploader::Validator`, and `X::Uploader::Account` methods, with `client:` as a keyword, as the object layer does
* Copy a client with some options changed with `X::Client#copy`, such as `client.copy(base_url: "https://api.x.com/1.1/")` for the v1.1 API or `client.copy(access_token: nil, access_token_secret: nil)` for an app-only client
* Raise `X::ResourceNotFound`, an `X::Error`, from `current_user` and the new `find!`, `find_user!`, `find_post!`, `find_list!`, `find_space!`, and `find_direct_message!`, so a missing resource is an error a caller can rescue in one place
* Replace the stubs among some resources with the full resources in parallel batches with `X::User.hydrate_all` and its equivalents
* Accept a username with a leading at sign in `find_user`, `find_users`, and `X::User.find_all_by_username`
* Add `X::DirectMessage#from?`, `X::Post#coordinates`, `permalink`, the x.com address of a post, user, list, or community, and `uri`, the same address as a `URI`
* Match resources against `case/in` patterns: `deconstruct` gives the identifier and `deconstruct_keys` every attribute the resource declares, read as its own method reads it, so `post in {like_count: 100..}` matches a metric the API nests
* Accept the responses of `X::Uploader::Media.upload` directly as the `media_ids:` of `create_post`
* Load `x-uploader` from `require "x"`, so `X::Uploader::Media` and `X::Uploader::Account` need no further require
* Scan a cursor with nothing but identifiers with `stubs`, and check a relationship without fetching every page with `user.follows?` and `list.member?`
* Resolve the posts a post or direct message refers to with `references`, and pair `liked_by` with `reposted_by` on `X::Post`, beside `reposts`, the reposts themselves, each a post by the user who reposted it
* Add `X::Post#urls` and `X::Post#expanded_text`, the text with every shortened link replaced by the URL it stands for
* Look up a user by identifier when given an Integer and by username when given a String, so an account whose username is all digits is found by name; everywhere else, such as `follow`, `from_id`, and `find_post`, an identifier that is not a number raises `ArgumentError`, rather than reach the API as a username it would take for an identifier
* Name the interface after posts rather than tweets, including `post_count`, `pinned_post_id`, `most_recent_post_id`, `edit_history_post_ids`, `note_post`, `referenced_posts`, and `repost_count`; the tweet-named methods, such as `create_tweet`, `tweets`, and `retweet_count`, remain as aliases
* Add `inspect` to `Client` and the authenticators that never reveals credentials
* Preserve custom headers passed to `get`, `post`, `put`, and `delete` across redirects
* Count the posts that match a query with `X::Post.count` and `X::Post.count_all`, or by period with `X::Post.counts` and `X::Post.counts_all`, and on a client with `count_posts`, `count_all_posts`, `post_counts`, and `all_post_counts`, which have tweet-named aliases; a client that signs with OAuth 1.0a counts with a copy that authenticates as the app, since the counts endpoints refuse OAuth 1.0a
* Report the partial errors of a successful response as `X::Problem` objects: `problems` on a resource and on each page of a cursor, a block given to a finder, which receives each problem, and `X::ResourceNotFound#problems`, whose first problem explains the message
* Pass an `X::Response` to the `on_response` of a client after every request, and for each object a stream delivers, which counts the resources the response returned with `resource_counts` and reads its rate limits with `rate_limits` and `rate_limit`
* Retry a request refused for a rate limit after the limit resets, up to `max_rate_limit_retries` times, which is 0 by default, for a limit that resets within `max_rate_limit_wait` seconds, which is 900 by default; a refusal that does not say when its limit resets waits a minute, doubling for each retry after
* Refresh an OAuth 2.0 access token when it expires, given the `expires_at:` of `X::Client`, a `Time`, since anything else raises `ArgumentError`, or when the API rejects it with 401 Unauthorized, sending the request again with the new token, and forgetting the expiration time when a refresh reports no lifetime, rather than refreshing again on every request; a lock lets requests on several threads refresh once, and `on_token_refresh:`, or the `on_refresh` of `X::OAuth2Authenticator`, receives the authenticator after each refresh to store its tokens
* Read the status of an `X::HTTPError` as an Integer with `status`, as `X::Response#status` reads it, beside `code`, the String that `Net::HTTP` gives
* Keep connections open between requests to the same host, up to eight idle per host, so a request no longer opens a TCP and TLS connection of its own; a connection whose request fails is closed, `X::Connection#close` closes the idle ones, a change of proxy or debug output opens new ones, and a forked process opens its own and leaves its parent's open when it closes them
* Authenticate as the app with `X::Client#app_only`, a copy of a client that signs with OAuth 1.0a, which fetches the app's bearer token once and reuses it
* Stream with app-only authentication from a client that signs with OAuth 1.0a, since the stream endpoints refuse it
* Stream with `X::StreamingClient`, which `X::Client#streaming` builds from a client, sharing its credentials, base URL, parsing classes, and `on_response` hook while keeping the settings of a long-lived connection
* Reconnect a stream that ends or drops, or that delivers a line that is not JSON, which raises `X::InvalidResponse` rather than `JSON::ParserError`, backing off as X recommends, up to the `max_reconnects` of the streaming client, which is unlimited by default; a rate limit waits until it resets, or from a minute, doubling each attempt
* Read a stream with the `read_timeout` of the streaming client, 30 seconds by default, half again the 20-second interval of the keep-alive X sends, so a stream that goes quiet reconnects rather than waiting for the timeout of an ordinary request
* Report how many posts the app's project has read with `X::Usage.find` and `client.usage`, including its monthly cap and its usage by day and by app
* Take the authenticated user's ID for actions from the prefix of an OAuth 1.0a access token, with `current_user_id`, instead of requesting `users/me`
* Refresh the tokens of a public OAuth 2.0 client, such as a native or single-page app, given a `client_id`, `access_token`, and `refresh_token` without a `client_secret`; the refresh sends the client ID in its body rather than authenticating with a secret
* Read the number of photos and videos a user has posted with `X::User#media_count`
* Bookmark a post and remove the bookmark with `bookmark` and `unbookmark` on `X::User` and `X::Client`, beside the `bookmarks` cursor that reads them
* Follow, unfollow, pin, and unpin a list with `follow_list`, `unfollow_list`, `pin_list`, and `unpin_list` on `X::User` and `X::Client`, and read a user's pinned lists with `X::User#pinned_lists`
* Quote a post with the `quote:` of `create_post` and `X::Post.create`, which builds the `quote_tweet_id` of the new post
* Hide a reply to a post of the authenticated user, and show it again, with `X::Post#hide` and `#unhide`, `X::Post.hide` and `.unhide`, and `hide_reply` and `unhide_reply` on the client
* Authorize an app to act for a user with the OAuth 2.0 authorization code flow and PKCE: `X::OAuth2Authorization` builds the URL that asks the user, with a state and code verifier to store until X redirects back, and exchanges the code of the redirect for `credentials` or a `client`, raising `X::AuthorizationError`, whose `error_code` is the OAuth 2.0 error code, when the user declines, the state does not match, X refuses the code, or the redirect is not a valid URL; a nil or empty state raises `ArgumentError`, since it would accept the redirect of any authorization
* Change several credentials at once with `X::Client#update_credentials`, which builds the authenticator once, so rotating an OAuth 1.0a access token and its secret never signs a request with a mismatched pair, and raises `ArgumentError` for credentials that do not form a complete set
* Start a group conversation of direct messages with `X::DirectMessage.create_group` and `create_group_direct_message` on the client, send to any conversation with `X::DirectMessage.create_in` and `create_direct_message_in`, and read any conversation with `X::DirectMessage.in_conversation` and `direct_messages_in`, each given a message of the conversation or its identifier; the client methods have `create_group_dm`, `create_dm_in`, and `dms_in` aliases
* Search spaces with `X::Space.search` and `search_spaces` on the client, a cursor over the live or scheduled spaces that match a query
### Changed
* Require Ruby 3.4 or later
* Hydrate the stubs of a page together, in one batch lookup for the whole page rather than one request per stub, so walking `user.followers.stubs` costs a request per page
* Split the object methods of the client into `X::Objects::API::Lookups` and `X::Objects::API::Actions`, which `X::Objects::API` includes together, `X::Objects::API::Lookups` into one module per kind of resource: `Users`, `Posts`, `Lists`, `Spaces`, `Communities`, and `DirectMessages`, and `X::Objects::API::Actions` into one module per kind of action: `Posts`, `Lists`, `DirectMessages`, `Relationships`, and `Engagement`
* Raise `X::ResourceNotFound` instead of `KeyError` from `current_user` when the API returns no user
* Read only the rate limits a response reports in full, with a limit, remaining requests, and reset time, so `X::TooManyRequests#retry_after` no longer raises `KeyError` for a response without a reset time
* Return the identifiers of users, posts, lists, direct messages, communities, and polls as Integers, along with the attributes that refer to them, such as `author_id`, `owner_id`, and `participant_ids`; space and place identifiers, media keys, and `dm_conversation_id`, which are not numbers, remain Strings
* Use the names the X API documentation gives: request `post.fields` and the `referenced_posts`, `edit_history_post_ids`, `pinned_post_id`, and `most_recent_post_id` expansions, and read `referenced_posts`, `edit_history_post_ids`, `note_post`, `pinned_post_id`, `most_recent_post_id`, `repost_count`, `post_count`, and included `posts`; the identifiers of referenced resources come with their expansions rather than as fields, and the authors of referenced posts are no longer expanded, since the documentation offers no expansion for them
* Send requests to `api.x.com` rather than `api.twitter.com` by default, the host of the token endpoints, the uploads, and the API's documentation
* Rename `X::User.me` to `X::User.current`, the request behind `current_user`
* Rename `X::Objects::Actions`, the follow, block, mute, like, and repost methods of `X::User`, to `X::Objects::Relationships`, so it no longer shares a name with `X::Objects::API::Actions`
* Raise `X::UnsupportedOperation`, an `X::Error`, from `X::List.find_all`, since the API has no batch lookup of lists, instead of sending a request that fails; the object layer raises it for anything else the API offers no way to do, such as hydrating `X::Media` or requesting the identifiers alone of a resource without a fields parameter
* Take the recipient and text of a direct message as the positional arguments of `create_direct_message`, in place of `to:` and `text:`, since both are required
* Derive the v1.1 client of `X::Uploader::Account` from the client it is given with `copy`, so it keeps the timeouts, proxy, and other settings
* Mark `X::RequestBuilder`, `X::RedirectHandler`, `X::ResponseParser`, `X::StreamParser`, `X::RateLimitHandler`, and `X::ReconnectHandler` as `@api private`, the internals of `X::Client` and `X::StreamingClient`, whose settings they expose, so that they can change within 1.x
* Raise `Errno::ENOENT` from the uploaders for a file that does not exist, and `X::Uploader::MediaProcessingFailed`, an `X::Error` whose `status` holds what X reported and whose message is its reason, for media that fails to process, instead of `RuntimeError`
* Move `X::InvalidMediaType` to `X::Uploader::InvalidMediaType`, beside the uploaders that raise it
* Rename `X::ConnectionException`, the error for 409 Conflict, to `X::Conflict`, after its status like every other HTTP error
* Rename `X::OAuthAuthenticator` to `X::OAuth1Authenticator`, beside `X::OAuth2Authenticator`
* Move the HTTP client into `x-core`, under `lib/x/core`, and the uploaders into `x-uploader`, under `lib/x/uploader`
* Rename `X::MediaUploader` to `X::Uploader::Media`, `X::AccountUploader` to `X::Uploader::Account`, and `X::MediaUploadValidator` to `X::Uploader::Validator`, under an `X::Uploader` module that holds the gem's version, since `X::Media` is the media resource
* Rename `upload_profile_image_binary` and `upload_profile_banner_binary` to `update_profile_image_binary` and `update_profile_banner_binary`, the binary forms of `update_profile_image` and `update_profile_banner`
* Wrap every network failure in `NetworkError`, so a stream reconnects after it rather than stopping: `IOError`, which includes `EOFError`; `SystemCallError`, which includes every `Errno` error, such as `Errno::ECONNABORTED` and `Errno::ENETDOWN`; `Timeout::Error`, which includes `Net::WriteTimeout`; `Net::ProtocolError`, which a proxy that refuses to open a tunnel raises; `Zlib::Error`, for a compressed body cut off mid-response; and `Net::HTTPBadResponse`
* Stop following redirects after exactly `max_redirects` hops instead of one more
* Raise `KeyError` from `X::Uploader::Media.chunked_upload` and `X::Uploader::Media.await_processing` when the media has no `"id"`, instead of requesting a URL with an empty ID
* Sign OAuth 1.0a requests with the [simple_oauth](https://github.com/laserlemon/simple_oauth) gem, in place of the signing code `X::OAuthAuthenticator` carried; it keeps the same credentials and produces the same header
* Build and parse the OAuth 2.0 token refresh with simple_oauth, in place of the request and response handling `X::OAuth2Authenticator` carried; it sends the same request and still returns the token response
* Raise `ArgumentError` from `X::Client.new`, and so from `copy`, for credentials that do not form a complete set, instead of sending requests without credentials, or authenticating as the app when an access token lacks its secret; the setters change one credential at a time, and `update_credentials` changes several at once
* Raise `X::InvalidResponse`, an `X::Error` that holds the response, for a successful response whose body is not JSON, such as the page of a proxy or captive portal, instead of returning nil as though the response had no body; a successful response without a body still returns nil
* Move `stream` from `X::Client` to `X::StreamingClient`, so that the client carries no streaming settings
* Raise `X::AuthorizationError`, an `X::Error`, when X refuses to refresh an OAuth 2.0 token or to issue an app-only bearer token, rather than a bare `X::Error`, with the OAuth 2.0 `error_code`, such as `invalid_request` for a refresh token that was revoked or already used, and the HTTP `status`, which tells a refusal from a failure of the token endpoint
* Return nil from `X::TooManyRequests#reset_at`, `#reset_in`, and `#retry_after` when the response does not say when the limit resets, instead of `Time.at(0)` and 0, which told a caller to retry at once
* Mark `X::Connection#perform` and `#perform_stream`, which take a `Net::HTTPRequest`, and `X::OAuth2Authenticator#refresh_rejected_token!` as `@api private`, the internals through which `X::Client` sends requests and refreshes a rejected token, so that they can change within 1.x
* Make `X::Objects::Resource#includes` private, and document the `includes:`, `hydrated:`, and `batch:` of `X::Objects::Resource.new` and `from_id` and the `limit:` and `total:` of `X::Cursor.new` as internal to the object layer, so that they can change within 1.x
* Mark `X::Uploader::Validator` as `@api private`, and make the MIME type and media category tables of `X::Uploader::Media`, the block constants of `X::Uploader::Gif`, and `X::Uploader::JSON_CLASSES` private constants, so that they can change within 1.x
### Removed
* Remove `X::Uploader::Account::MIME_TYPE_MAP`, which nothing read
* Remove the `boundary:` of the upload methods of `X::Uploader::Media` and `X::Uploader::Account`, which each upload now generates for itself, since a caller has no reason to choose the boundary of a multipart body
* Make `X::HTTPError#error_message`, `#message_from_json_response`, and `#json?` private; they build the message an error is initialized with, which `message` returns
* Remove `require "x/media_uploader"` and `require "x/account_uploader"`; require `x`, `x/uploader/media`, or `x/uploader/account` instead
* Remove `X::OAuthAuthenticator::OAUTH_SIGNATURE_ALGORITHM`, which named the digest of the signing code that is gone
* Remove `X::OAuth2Authenticator::REFRESH_GRANT_TYPE`, which named the grant type simple_oauth now sends
* Remove the `base64` dependency from `x-core`, which encodes no Base64 of its own now that simple_oauth builds the Basic credentials
* Remove the setters of `X::RateLimit`, `X::BearerTokenAuthenticator`, `X::OAuth1Authenticator`, and `X::OAuth2Authenticator`, whose attributes are now read-only; change a credential with the setters of `X::Client`, which build a new authenticator, and a token refresh replaces the tokens of an OAuth 2.0 authenticator under its lock

### Fixed
* Parse the responses of the uploaders into Hashes and Arrays whatever the `default_object_class` and `default_array_class` of the client, so a client that defaults to another class, such as `OpenStruct`, uploads media, adds metadata, and updates a profile image or banner instead of raising `NoMethodError`
* Call `on_token_refresh`, and the `on_refresh` of `X::OAuth2Authenticator`, once the refresh releases its lock, so the callable can send a request with the client, such as looking up the user whose tokens it stores, rather than raise `ThreadError` for recursive locking
* Resolve a relative redirect against the URL of the request it redirects, rather than the base URL, so a redirect from a request to another host, such as `upload.x.com`, stays on that host with its credentials
* Build the message of an `X::HTTPError` from a body that is not the JSON its content type claims, such as an empty or HTML body, or whose errors have no `message`, instead of raising `JSON::ParserError`, `KeyError`, or `TypeError` in place of the error, so a stream reconnects and a chunk upload retries after such a server error; an error without a `message` gives its `detail` or `title`
* Look up `current_user` again once the client's credentials change, rather than keep returning the user of the credentials it had when first asked
* Stop the batches of a parallel lookup, such as `find_users`, that have not begun once one fails, and raise its error after the batches already begun have finished, instead of sending every remaining batch, which the API bills, before raising
* Request the largest page each search allows: 500 posts from `search_all_posts`, or 100 when the request asks for context annotations, as the default fields do, and 1,000 users from `search_users`, instead of 100 from each
* Accept the `amplify_video` media category, which the API documents and the validator rejected, uploading it in chunks and awaiting its processing, and subtitle such a video with the `media_category: "AmplifyVideo"` of `add_subtitles`
* Upload every media type the API documents: WebM, QuickTime, and MPEG-TS videos, WebVTT subtitles, BMP, TIFF, and progressive JPEG images, and glTF and USDZ models, instead of sending any video as MP4 and any subtitles as SubRip whatever the file
* Give up waiting for media to process after ten minutes, or the `processing_timeout:` of `upload` and `await_processing`, raising `X::Uploader::MediaProcessingTimeout` with the last status, and wait at least a second between checks when X asks for no wait, instead of polling in a tight loop forever
* Wait before retrying a chunk that failed with a server or network error, a second and then two, instead of retrying at once
* Upload the chunks of a video no more than four at a time, or the `concurrency:` of `chunked_upload`, reading each from the file as it is sent, instead of starting a thread per chunk and first copying every chunk into a temporary file; a chunk that fails stops the chunks not yet begun
* Read the tokens of the last OAuth 2.0 refresh from `X::Client#access_token`, `refresh_token`, and `expires_at`, and share the authenticator with a copy that holds the same credentials, so that neither `copy` nor a changed credential brings back a refresh token X no longer accepts
* Fetch an app-only bearer token and refresh an OAuth 2.0 token over the client's connection, so the proxy, timeouts, and debug output of a client apply to token requests as they do to every other request
* Drop the credentials, and any `Authorization` header passed in `headers:`, named by a String or a Symbol in any case, when a redirect leads to another scheme, host, or port, so a redirect cannot send them to a host they were not meant for
* Send no `Authorization` header from a client without credentials, rather than an empty one
* Raise `X::ClientError` or `X::ServerError` for a 4xx or 5xx status that no error class names, such as 405 or 501, instead of `X::HTTPError`, so a stream reconnects and a chunk upload retries after any server error
* Link each gem's `changelog_uri` to the `main` branch, which the repository uses, rather than `master`
* Upload subtitles as `text/srt` in chunks, as the API requires, instead of as `application/x-subrip` in one request, which it rejects
* Send the authenticator on every redirected request, not only the first
* Sign a form-encoded request body, which OAuth 1.0a requires and the signature left out, so such a request no longer fails to authenticate
* Sign a query parameter that repeats once per value, rather than signing only one of the values
* Sign the normalized URL, so a request to a host with no path signs the `/` the server sees
* Form-encode the client credentials before Basic authentication on token refresh, as RFC 6749 Section 2.3.1 requires, so a client ID or secret containing a reserved character authenticates
* Leave the user and password of a proxy out of the message of an invalid proxy URL, and out of `X::Connection#inspect`, which now summarizes the proxy URL and timeouts; raise `ArgumentError` rather than `URI::InvalidURIError` for a proxy URL that cannot be parsed; and keep the proxy an invalid URL would have replaced
* Remove a proxy by setting `proxy_url` to nil, which raised `ArgumentError`, and decode a percent-encoded proxy user and password, which were sent to the proxy still encoded
* Return nil from `X::Connection#proxy_host` and `#proxy_port` without a proxy, which raised `NoMethodError`
* Connect to an `https://` proxy over TLS, rather than sending it the host to tunnel to and the proxy user and password in plaintext
* Raise `X::HTTPError` for a redirect that cannot be followed, such as 304 Not Modified or one whose location is missing, is not a valid URL, or is not an HTTP or HTTPS URL, instead of `KeyError`, `URI::InvalidURIError`, or `ArgumentError`
* Raise `X::UnsupportedOperation` from `X::DirectMessage.find_all`, and so from `hydrate_all`, since the API has no batch lookup of direct message events, instead of sending an `ids` parameter the endpoint does not take
* End a `base_url` without a trailing slash with one, so that `base_url: "https://api.x.com/2"` sends a request for `users/me` to `/2/users/me` rather than `/users/me`
* Raise `ArgumentError` from `X::Uploader::Media.chunked_upload`, before any request, for a `chunk_size_mb` that is not positive or a `concurrency` less than one, which initialized an upload and finalized it without a chunk, or raised `ArgumentError: negative array size` after initializing it
* Stop sending a credential a setter clears, such as `client.bearer_token = nil`, which kept the authenticator of the cleared credential while the client reported it as nil
* Send a `Time` passed as a query parameter, such as the `start_time:` of `count_posts` or the `params:` of `get`, in UTC in the ISO 8601 form the API takes, rather than as `Time#to_s`, which the API refuses
* Upload in chunks from a class that includes `X::Uploader::Media`, which extended the chunk upload methods onto the module alone, so `chunked_upload` raised `NoMethodError` from an instance of the class
* Send the media category of an upload in lowercase, as the API documents it, rather than as given, since the uploaders accept a category in any case, such as `TWEET_VIDEO`
* Round a fractional `chunk_size_mb` up to a whole number of bytes, rather than read each chunk at a fractional offset, which skipped a byte between some chunks and uploaded a corrupt file

## [0.19.0] - 2026-03-01
* Add streaming support for filtered stream and volume stream endpoints

## [0.18.0] - 2026-01-06
* Add OAuth 2.0 authentication with token refresh support (d4c03cb)
* Add AccountUploader for profile image and banner uploads (7833dd2)
* Raise InvalidMediaType error for unsupported file extensions (2b6eacc)
* Prioritize errors array over title/detail in error messages (75279b9)

## [0.17.0] - 2025-12-02
* Add MediaUploader.upload_binary method (9f2f108)
* Don't forward filename during media upload (492214d)

## [0.16.0] - 2025-06-24
* Remove media_type parameter from non-chunked upload and append methods (f1f38b5)
* Fix media upload (dcb418a)
* Add await_processing! method to handle media upload failures (6cfc973)
* Move media_category in body for media upload (b790636)

## [0.15.4] - 2025-05-02
* Use dedicated endpoints for chunked media upload (d54d0d0)

## [0.15.3] - 2025-04-24
* Add missing base64 dependency (3ca8512)
* Set binary read for media files to be uploaded (fd066e6)

## [0.15.2] - 2025-03-28
* Use media_id instead of media_key to upload media (f1dd577)

## [0.15.1] - 2025-03-24
* Fix bug in MediaUploader#await_processing (136dff8)
* Refactor RedirectHandler#build_request (fd379c3)
* Escape space in query string as %20, not + (2d2df75)
* Don't escape commas in query parameters (e7d9056)

## [0.15.0] - 2025-02-06
* Change media upload to use the API v2 endpoints (eca2b88)

## [0.14.1] - 2023-12-20
* Fix infinite loop when an upload fails (5dfc604)

## [0.14.0] - 2023-12-08
* Allow passing custom objects per-request (768889f)

## [0.13.0] - 2023-12-04
* Introduce X::RateLimit, which is returned with X::TooManyRequests errors (196caec)

## [0.12.1] - 2023-11-28
* Ensure split chunks are written as binary (c6e257f)
* Require tmpdir in X::MediaUploader (9e7c7f1)

## [0.12.0] - 2023-11-02
* Ensure Authenticator is passed to RedirectHandler (fc8557b)
* Add AUTHENTICATION_HEADER to X::Authenticator base class (85a2818)
* Introduce X::HTTPError (90ae132)
* Add `code` attribute to error classes (b003639)

## [0.11.0] - 2023-10-24
* Add base Authenticator class (8c66ce2)
* Consistently use keyword arguments (3beb271)
* Use patern matching to build request (4d001c7)
* Rename ResponseHandler to ResponseParser (498e890)
* Rename methods to be more consistent (5b8c655)
* Rename MediaUpload to MediaUploader (84f0c15)
* Add mutant and kill mutants (b124968)
* Fix authentication bug with request URLs that contain spaces (8de3174)
* Refactor errors (853d39c)
* Make Connection class threadsafe (d95d285)

## [0.10.0] - 2023-10-08
* Add media upload helper methods (6c6a267)
* Add PayloadTooLargeError class (cd61850)

## [0.9.1] - 2023-10-06
* Allow successful empty responses (06bf7db)
* Update default User-Agent string (296b36a)
* Move query parameter escaping into RequestBuilder (56d6bd2)

## [0.9.0] - 2023-09-26
* Add support for HTTP proxies (3740f4f)

## [0.8.1] - 2023-09-20
* Fix bug where setting Connection#base_uri= doesn't update the HTTP client (d5a89db)

## [0.8.0] - 2023-09-14
* Add (back) bearer token authentication (62e141d)
* Follow redirects (90a8c55)
* Parse error responses with Content-Type: application/problem+json (0b697d9)

## [0.7.1] - 2023-09-02
* Fix bug in X::Authenticator#split_uri (ebc9d5f)

## [0.7.0] - 2023-09-02
* Remove OAuth gem (7c29bb1)

## [0.6.0] - 2023-08-30
* Add configurable debug output stream for logging (fd2d4b0)
* Remove bearer token authentication (efff940)
* Define RBS type signatures (d7f63ba)

## [0.5.1] - 2023-08-16
* Fix bearer token authentication (1a1ca93)

## [0.5.0] - 2023-08-10
* Add configurable write timeout (2a31f84)
* Use built-in Gem::Version class (066e0b6)

## [0.4.0] - 2023-08-06
* Refactor Client into Authenticator, RequestBuilder, Connection, ResponseHandler (6bee1e9)
* Add configurable open timeout (1000f9d)
* Allow configuration of content type (f33a732)

## [0.3.0] - 2023-08-04
* Add accessors to X::Client (e61fa73)
* Add configurable read timeout (41502b9)
* Handle network-related errors (9ed1fb4)
* Include response body in errors (a203e6a)

## [0.2.0] - 2023-08-02
* Allow configuration of base URL (4bc0531)
* Improve error handling (14dc0cd)

## [0.1.0] - 2023-08-02
* Initial release

[unreleased]: https://github.com/sferik/x-ruby/compare/v0.19.0...HEAD
[1.0.0]: https://github.com/sferik/x-ruby/compare/v0.19.0...v1.0.0
[0.19.0]: https://github.com/sferik/x-ruby/compare/v0.18.0...v0.19.0
[0.18.0]: https://github.com/sferik/x-ruby/compare/v0.17.0...v0.18.0
[0.17.0]: https://github.com/sferik/x-ruby/compare/v0.16.0...v0.17.0
[0.16.0]: https://github.com/sferik/x-ruby/compare/v0.15.4...v0.16.0
[0.15.4]: https://github.com/sferik/x-ruby/compare/v0.15.3...v0.15.4
[0.15.3]: https://github.com/sferik/x-ruby/compare/v0.15.2...v0.15.3
[0.15.2]: https://github.com/sferik/x-ruby/compare/v0.15.1...v0.15.2
[0.15.1]: https://github.com/sferik/x-ruby/compare/v0.15.0...v0.15.1
[0.15.0]: https://github.com/sferik/x-ruby/compare/v0.14.1...v0.15.0
[0.14.1]: https://github.com/sferik/x-ruby/compare/v0.14.0...v0.14.1
[0.14.0]: https://github.com/sferik/x-ruby/compare/v0.13.0...v0.14.0
[0.13.0]: https://github.com/sferik/x-ruby/compare/v0.12.1...v0.13.0
[0.12.1]: https://github.com/sferik/x-ruby/compare/v0.12.0...v0.12.1
[0.12.0]: https://github.com/sferik/x-ruby/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/sferik/x-ruby/compare/v0.10.0...v0.11.0
[0.10.0]: https://github.com/sferik/x-ruby/compare/v0.9.1...v0.10.0
[0.9.1]: https://github.com/sferik/x-ruby/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/sferik/x-ruby/compare/v0.8.1...v0.9.0
[0.8.1]: https://github.com/sferik/x-ruby/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/sferik/x-ruby/compare/v0.7.1...v0.8.0
[0.7.1]: https://github.com/sferik/x-ruby/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/sferik/x-ruby/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/sferik/x-ruby/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/sferik/x-ruby/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/sferik/x-ruby/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/sferik/x-ruby/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/sferik/x-ruby/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/sferik/x-ruby/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sferik/x-ruby/releases/tag/v0.1.0
