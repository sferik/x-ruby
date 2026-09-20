# Security Policy

## Supported versions

`x`, `x-core`, `x-uploader`, `x-streaming`, and `x-objects` are released from this repository in lockstep, at the
version in [VERSION](https://github.com/sferik/x-ruby/blob/main/VERSION). Security fixes are released for the latest 1.x
version of each gem. Versions before 1.0 are not supported;
[UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) covers what code written for 0.19 needs.

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
`Authorization` header of every request. Four things are worth knowing:

* `X::Client#inspect` prints the base URL and the class of the authenticator, and no token or secret, so a client
  is safe to log or to show in a backtrace. An OAuth 2.0 authenticator adds its client ID and expiration time, which
  are not secret. A client, a streaming client, an authenticator, and an `X::OAuth2Authorization` raise `TypeError`
  from `Marshal.dump`, `YAML.dump`, `as_json`, and `to_json` rather than write their credentials in the clear, so a
  client held in a Hash is not cached with them, nor written with the arguments of a job a queue keeps as YAML, nor
  rendered as JSON into a response or a log, and a resource or a page of them writes plain data to any of them
  without the client it holds. The `X::OAuth2Tokens` that `save_tokens` is passed do marshal, and write themselves
  as YAML, tokens and all, since they are what is stored; keep what they write where you would keep the tokens.
* `debug_output` is not. It writes every request and response to the IO it is given, headers included, so it writes
  the `Authorization` header of each request, and the tokens in the body of an OAuth 2.0 token refresh. Send it to a
  file you control, never to a log that is shipped elsewhere, and leave it unset in production.
* A client that is given no `proxy_url` takes the proxy the environment names, in `https_proxy` or `http_proxy`, as
  most HTTP clients do. Requests then reach X through whatever that names: a proxy of an HTTPS request is asked to
  tunnel it, so it sees the host and not the credentials, but one that terminates TLS, with a certificate the
  process trusts, sees every header. Set `no_proxy`, or pass a `proxy_url` of your own, where the environment is not
  yours to trust.
* A request that leaves the origin of the `base_url`, and a redirect that leads off it, is sent without the
  `Authorization` header the authenticator signs and without any `Authorization`, `Cookie`, or
  `Proxy-Authorization` header of the client or the request. Those three names are the whole of what is dropped. A
  credential carried in a header of another name, such as one a gateway of your own reads, is sent wherever the
  request goes, so pass it to the request that needs it rather than to `X::Client.new`, which sends the headers it
  is given with every request the client makes.

An OAuth 2.0 refresh token is accepted once: a refresh returns a new one, and `save_tokens` is passed the
`X::OAuth2Tokens` of each refresh so that the new tokens can be stored. Dropping them leaves the stored refresh token
useless, and the user has to authorize the app again. A `save_tokens` that raises, as one whose store is
briefly down may, raises `X::TokenReportFailed`, whose `tokens` are the new ones, so they can be stored again.
Processes that share the tokens of a user pass `load_tokens` as well, so that a refresh reads the tokens another
process stored rather than spend a refresh token already spent. The authenticator keeps its access token and refresh
token private, as a client does, so neither reads off `client.authenticator`.
