# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
* Split the gem into gems released in lockstep: `x-core` (the HTTP client), `x-media` (media, profile image, and banner uploads), `x-objects` (resource objects), and `x` (a meta-gem that depends on all three and mixes the object methods into `X::Client`)
* Add immutable, thread-safe resource classes: `X::User`, `X::Post` (aliased as `X::Tweet`), `X::List`, `X::DirectMessage`, `X::Space`, `X::Media`, `X::Poll`, and `X::Place`
* Compare resources by class and ID with `==`, `eql?`, and `hash`, so the same resource fetched in different requests is equal
* Resolve references such as `post.author` and `post.replied_to` to included objects or ID stubs, sharing one object per resource within a response
* Add `hydrate`, which fetches and memoizes the full resource, and `refresh`, which fetches it again
* Add `X::Cursor`, an `Enumerable` collection that requests the maximum page size, fetches pages lazily, caches them, and offers `refresh` and `prefetch`
* Look up users and posts by ID in parallel batches of 100 with `X::User.find_all` and `X::Post.find_all`
* Add `find_user`, `find_users`, `me`, `find_post`, `find_posts`, `search`, `search_all`, `create_post`, `delete_post`, `find_list`, `find_space`, `direct_messages`, `create_direct_message`, `follow`, `unfollow`, `like`, `unlike`, `repost`, and `unrepost` to `X::Client`
* Look up a user by identifier when given an Integer and by username when given a String, so an account whose username is all digits is found by name
* Name the interface after posts rather than tweets, including `post_count`, `pinned_post_id`, `most_recent_post_id`, `edit_history_post_ids`, `note_post`, and `repost_count`; the tweet-named methods, such as `create_tweet`, `tweets`, and `retweet_count`, remain as aliases
* Add `inspect` to `Client` and the authenticators that never reveals credentials
* Preserve custom headers passed to `get`, `post`, `put`, and `delete` across redirects

### Changed
* Move the HTTP client into `x-core`, under `lib/x/core`, and the uploaders into `x-media`, under `lib/x/media`; `require "x/media_uploader"` and `require "x/account_uploader"` still work
* Wrap `EOFError`, `SocketError`, `Net::WriteTimeout`, `Errno::ETIMEDOUT`, and `Errno::EHOSTUNREACH` in `NetworkError`
* Stop following redirects after exactly `max_redirects` hops instead of one more
* Raise `KeyError` from `MediaUploader.chunked_upload` and `MediaUploader.await_processing` when the media has no `"id"`, instead of requesting a URL with an empty ID
* Sign OAuth 1.0a requests with the [simple_oauth](https://github.com/laserlemon/simple_oauth) gem, in place of the signing code `X::OAuthAuthenticator` carried; it keeps the same credentials and produces the same header
* Build and parse the OAuth 2.0 token refresh with simple_oauth, in place of the request and response handling `X::OAuth2Authenticator` carried; it sends the same request and still returns the token response and raises `X::Error`

### Removed
* Remove `X::OAuthAuthenticator::OAUTH_SIGNATURE_ALGORITHM`, which named the digest of the signing code that is gone
* Remove `X::OAuth2Authenticator::REFRESH_GRANT_TYPE`, which named the grant type simple_oauth now sends
* Remove the `base64` dependency from `x-core`, which encodes no Base64 of its own now that simple_oauth builds the Basic credentials

### Fixed
* Send the authenticator on every redirected request, not only the first
* Sign a form-encoded request body, which OAuth 1.0a requires and the signature left out, so such a request no longer fails to authenticate
* Sign a query parameter that repeats once per value, rather than signing only one of the values
* Sign the normalized URL, so a request to a host with no path signs the `/` the server sees
* Form-encode the client credentials before Basic authentication on token refresh, as RFC 6749 Section 2.3.1 requires, so a client ID or secret containing a reserved character authenticates

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
