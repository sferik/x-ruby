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
