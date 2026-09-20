# Security Policy

## Supported versions

`x`, `x-core`, `x-uploader`, and `x-objects` are released from this repository in lockstep, at the version in
[VERSION](VERSION). Security fixes are released for the latest 1.x version of each gem. Versions before 1.0 are not
supported; [UPGRADING.md](UPGRADING.md) covers what code written for 0.19 needs.

| Version | Supported |
| --- | --- |
| 1.x | ✅ |
| 0.x | ❌ |

## Reporting a vulnerability

Report a vulnerability privately, with [Report a
vulnerability](https://github.com/sferik/x-ruby/security/advisories/new), rather than by opening an issue or a pull
request, which are public. Reports are acknowledged as soon as possible, and a fix is released with an advisory that
credits the reporter, unless the reporter asks otherwise.

Include what you can:

* which gem, and which version
* what an attacker can do, and what they need in order to do it
* the smallest script that shows the problem
* the Ruby version and platform you saw it on

A vulnerability in the X API itself, rather than in these gems, belongs to X, and should be reported to X rather
than here.

## Handling credentials

The gems hold API keys, access tokens, and bearer tokens for as long as a client lives, and send them in the
`Authorization` header of every request. Two things are worth knowing:

* `X::Client#inspect` prints the base URL and the class of the authenticator, and no token or secret, so a client
  is safe to log or to show in a backtrace. An OAuth 2.0 authenticator adds its client ID and expiration time, which
  are not secret.
* `debug_output` is not. It writes every request and response to the IO it is given, headers included, so it writes
  the `Authorization` header of each request, and the tokens in the body of an OAuth 2.0 token refresh. Send it to a
  file you control, never to a log that is shipped elsewhere, and leave it unset in production.

An OAuth 2.0 refresh token is accepted once: a refresh returns a new one, and `on_token_refresh` is passed the
authenticator after each refresh so that the new tokens can be stored. Dropping them leaves the stored refresh token
useless, and the user has to authorize the app again.
