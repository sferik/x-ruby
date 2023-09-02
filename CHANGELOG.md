## [Unreleased]

## [0.7.0] - 2023-09-02

- Remove OAuth gem (7c29bb1)

## [0.6.0] - 2023-08-30

- Add configurable debug output stream for logging (fd2d4b0)
- Remove bearer token authentication (efff940)
- Define RBS type signatures (d7f63ba)

## [0.5.1] - 2023-08-16

- Fix bearer token authentication (1a1ca93)

## [0.5.0] - 2023-08-10

- Add configurable write timeout (2a31f84)
- Use built-in Gem::Version class (066e0b6)

## [0.4.0] - 2023-08-06

- Refactor Client into Authenticator, RequestBuilder, Connection, ResponseHandler (6bee1e9)
- Add configurable open timeout (1000f9d)
- Allow configuration of content type (f33a732)

## [0.3.0] - 2023-08-04

- Add accessors to X::Client (e61fa73)
- Add configurable read timeout (41502b9)
- Handle network-related errors (9ed1fb4)
- Include response body in errors (a203e6a)

## [0.2.0] - 2023-08-02

- Allow configuration of base URL (4bc0531)
- Improve error handling (14dc0cd)

## [0.1.0] - 2023-08-02

- Initial release
