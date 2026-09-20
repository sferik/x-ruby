# Changelog

All notable changes to `x-uploader` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

`x-uploader` is released in lockstep with the other gems of the [x-ruby](https://github.com/sferik/x-ruby) repository, at one version across `x-core`, `x-uploader`, `x-objects`, and `x`. This file holds the changes to the uploads; [the changelog of the repository](https://github.com/sferik/x-ruby/blob/main/CHANGELOG.md) holds the changes to every gem.

## [1.0.0] - 2026-09-20

The first release of `x-uploader`, which 1.0.0 split out of the `x` gem. The entries below are the changes since `x` 0.19, the last release before the split; see [UPGRADING.md](https://github.com/sferik/x-ruby/blob/main/UPGRADING.md) for the changes that code written for 0.19 needs.

### Added
* Split the gem into gems released in lockstep: `x-core` (the HTTP client), `x-uploader` (media, profile image, and banner uploads), `x-objects` (resource objects), and `x` (a meta-gem that depends on all three and mixes the object methods into `X::Client`); `x-uploader` and `x-objects` depend on `x-core`, which declares `X::Error`, the base class of every error the gems raise, and every other error named directly under `X`, though `x-objects` makes no request of its own and asks the client it is given to make them; each gem depends on the ones it needs with a pessimistic constraint on the version being released, so the lockstep holds while a patch of `x-core` still installs under the gems of the same minor
* Describe uploaded media with alt text, through the `alt_text:` of `X::Uploader::Media.upload` or `X::Uploader::Metadata.add_alt_text`, and attach uploaded subtitles to a video with `X::Uploader::Metadata.add_subtitles`
* Upload a GIF with a single frame as an image, since X fails to process it as a GIF, telling a still GIF from an animated one with `X::Uploader::Gif.animated?`
* Infer the media category of an upload from the file extension, upload a video in chunks, and wait for a video or an animated GIF to be processed, so `X::Uploader::Media.upload("cat.mp4", client:)` handles any file, taking the `media_type:`, `chunk_size_mb:`, and `concurrency:` of a chunked upload, none of which an upload in a single request sends, since the API types an image itself, and raising `ArgumentError` for any other keyword
* Take the file path, content, or media as the positional argument of the `X::Uploader::Media`, `X::Uploader::Validator`, and `X::Uploader::Account` methods, with `client:` as a keyword, as the object layer does
* Return an `X::Uploader::UploadedMedia` from `upload`, `upload_binary`, `chunked_upload`, `await_processing`, and `await_processing!`, and from `upload_media`, `upload_media_binary`, and `await_media_processing` on the client, in place of a Hash: a frozen object that reads the media's `id`, as an Integer, `media_key`, `bytesize`, `expires_at`, `processing_info`, `state`, and `check_after_secs`, tells `processing?`, `failed?`, and `ready?`, compares by its attributes, writes itself as its response with `as_json` and `to_json`, and still reads as the Hash with `[]`, `fetch`, which takes a default value and a block as `Hash#fetch` does, `dig`, `key?`, and `to_h`, so `media["id"]` and `media["size"]` work as they did; the uploaders and `create_post` take it wherever they take media, and `X::Uploader::MediaProcessingFailed#status` and `X::Uploader::MediaProcessingTimeout#status` hold it
* Add `upload_media`, `upload_media_binary`, `await_media_processing`, and `await_media_processing!`, which raises if processing failed where the other returns the status, `add_alt_text`, `add_subtitles`, `update_profile_image`, and `update_profile_banner` to `X::Client`, each of which calls an uploader with the client, as in `client.create_post("Look", media_ids: [client.upload_media("cat.jpg")])`; they are the methods of `X::Uploader::API`, which `x` includes into `X::Client`, and which code that depends on `x-core` and `x-uploader` alone can include itself
* Take the identifier of media, a String or an Integer, as well as the response of an upload, in `X::Uploader::Media.await_processing` and `await_processing!`, as `X::Uploader::Metadata.add_alt_text` and `add_subtitles` do
* Add `X::Uploader::Media::DEFAULT_CONCURRENCY`, the four chunks a chunked upload sends at once unless `concurrency:` says otherwise
* Rescue the failures of an upload alone with `X::Uploader::Error`, which `X::Uploader::InvalidMediaType`, `X::Uploader::MediaProcessingFailed`, and `X::Uploader::MediaProcessingTimeout` descend from, beside `X::Error`
* Name the media category of an upload with a Symbol, in any case, wherever a String is taken, as in `media_category: :tweet_video`
* Check whether a file uploads in chunks with `X::Uploader::Media.chunked_upload?`, and read the most a single upload request takes from `X::Uploader::Media::MAX_SIMPLE_UPLOAD_BYTES`
* Ship a `CHANGELOG.md` with `x-core`, `x-uploader`, and `x-objects`, holding the entries of this file that are changes to that gem, which the `changelog_uri` of each gemspec names in place of this file

### Changed
* Require Ruby 3.4 or later
* Send requests to `api.x.com` rather than `api.twitter.com` by default, the host of the token endpoints, the uploads, and the API's documentation
* Post the profile image and banner uploads of `X::Uploader::Account` to the absolute URL of the API v1.1 endpoint with the client they are given, so they keep its timeouts, proxy, and other settings, and reuse the connection it holds open, rather than build a copy of it, and its own connection pool, for every upload
* Raise `Errno::ENOENT` from the uploaders for a file that does not exist, and `X::Uploader::MediaProcessingFailed`, an `X::Error` whose `status` holds what X reported and whose message is its reason, for media that fails to process, instead of `RuntimeError`
* Move `X::InvalidMediaType` to `X::Uploader::InvalidMediaType`, beside the uploaders that raise it
* Move the HTTP client into `x-core`, under `lib/x/core`, and the uploaders into `x-uploader`, under `lib/x/uploader`
* Rename `X::MediaUploader` to `X::Uploader::Media`, `X::AccountUploader` to `X::Uploader::Account`, and `X::MediaUploadValidator` to `X::Uploader::Validator`, under an `X::Uploader` module that holds the gem's version, since `X::Media` is the media resource
* Rename `upload_profile_image_binary` and `upload_profile_banner_binary` to `update_profile_image_binary` and `update_profile_banner_binary`, the binary forms of `update_profile_image` and `update_profile_banner`
* Raise `KeyError` from `X::Uploader::Media.chunked_upload` and `X::Uploader::Media.await_processing` when the media has no `"id"`, instead of requesting a URL with an empty ID
* Make `X::Uploader::Validator`, `X::Uploader::Chunks`, `X::Uploader::Multipart`, and `X::Uploader::Utils`, which the uploaders validate, upload, and read files with, private constants, and make the MIME type and media category tables of `X::Uploader::Media`, the block constants of `X::Uploader::Gif`, and `X::Uploader::JSON_CLASSES` private constants, so that they can change within 1.x, and make `MAX_ATTEMPTS` and `RETRY_BACKOFF` private constants of `X::Uploader::Chunks`, which `X::Uploader::Media` no longer includes, so they are not constants of `X::Uploader::Media`
* Derive the chunk size of a chunked upload from the size of the file, so that a file of any size uploads within the 1,000 segments the API numbers, where 1 MB chunks refused a file larger than 1,000 MiB after uploading, and billing, about a gigabyte of it; the `chunk_size_mb:` of `upload` and `chunked_upload` is nil by default, which derives it
* Upload an animated GIF larger than `X::Uploader::Media::MAX_SIMPLE_UPLOAD_BYTES` in chunks, which the API takes up to 15 MB of, rather than in the single request it takes no more than 5 MB of
* Validate the `alt_text:` of `X::Uploader::Media.upload` before the upload rather than after it, raising `ArgumentError` for empty text or more than the 1,000 characters the API takes, so media that uploaded is no longer lost to a refusal of its alt text
* Read the identifier of `X::Uploader::UploadedMedia` as an Integer wherever the media reads it, so `media["id"]`, `media.fetch("id")`, `media.to_h`, and the JSON of `as_json` and `to_json` hold the number that `media.id` returns, rather than the String the API gave beside an `id` that converted it, and media whose identifier names no number raises `ArgumentError` when it is built rather than when it is read; the `media_ids:` of a post or a direct message still sends each identifier as a String

### Removed
* Remove `X::Uploader::Account::MIME_TYPE_MAP`, which nothing read
* Remove `X::Uploader::UploadedMedia#size`, the byte count of the media, which read as `Hash#size` would not; it is `bytesize`, beside the unchanged `media["size"]`
* Remove the `boundary:` of the upload methods of `X::Uploader::Media` and `X::Uploader::Account`, which each upload now generates for itself, since a caller has no reason to choose the boundary of a multipart body
* Remove `require "x/media_uploader"` and `require "x/account_uploader"`; require `x`, `x/uploader/media`, or `x/uploader/account` instead

### Fixed
* Raise `KeyError` from a chunked upload whose initialize response holds no media, naming what was missing, instead of `NoMethodError` on nil from the first chunk, and raise it before a chunk is uploaded and billed
* Parse the responses of the uploaders into Hashes and Arrays whatever the `default_object_class` and `default_array_class` of the client, so a client that defaults to another class, such as `OpenStruct`, uploads media, adds metadata, and updates a profile image or banner instead of raising `NoMethodError`
* Accept the `amplify_video` media category, which the API documents and the validator rejected, uploading it in chunks and awaiting its processing, and subtitle such a video with the `media_category: "AmplifyVideo"` of `add_subtitles`
* Upload every media type the API documents: WebM, QuickTime, and MPEG-TS videos, WebVTT subtitles, BMP, TIFF, and progressive JPEG images, and glTF and USDZ models, instead of sending any video as MP4 and any subtitles as SubRip whatever the file
* Upload an `.m4v`, `.avi`, or `.mkv` file as a video, in chunks, where `upload` inferred an image from any extension it did not know, read the whole file into memory, and sent it at once for X to refuse; an `.m4v` file is MP4, and an `.avi` or `.mkv` file, which the API documents no type for, is sent as MP4, for X to decide whether it can process it
* Give up waiting for media to process after ten minutes, or the `processing_timeout:` of `upload` and `await_processing`, raising `X::Uploader::MediaProcessingTimeout` with the last status, and wait at least a second between checks when X asks for no wait, instead of polling in a tight loop forever
* Wait before retrying a chunk that failed with a server or network error, a second and then two, instead of retrying at once
* Upload the chunks of a video no more than four at a time, or the `concurrency:` of `chunked_upload`, reading each from the file as it is sent, instead of starting a thread per chunk and first copying every chunk into a temporary file; a chunk that fails stops the chunks not yet begun
* Link each gem's `changelog_uri` to the `main` branch, which the repository uses, rather than `master`
* Upload subtitles as `text/srt` in chunks, as the API requires, instead of as `application/x-subrip` in one request, which it rejects
* Raise `ArgumentError` from `X::Uploader::Media.chunked_upload`, before any request, for a `chunk_size_mb` that is not positive, one that would need more than the 1,000 segments the API numbers, or a `concurrency` less than one, which initialized an upload and finalized it without a chunk, uploaded and billed about a gigabyte before the API refused segment 1,000, or raised `ArgumentError: negative array size` after initializing it
* Give a class that includes `X::Uploader::Media`, `X::Uploader::Account`, or `X::Uploader::Metadata` their public methods alone, which call the private modules `X::Uploader::Chunks`, `X::Uploader::Multipart`, and `X::Uploader::Utils` rather than mix methods such as `init`, `append`, `transfer`, `extension`, and `media_id` into the class, so such a class uploads in chunks, and a method it defines under one of those names no longer breaks an upload
* Stop the chunks of a chunked upload when an exception is raised in the thread that waits for them, such as a timeout or an interrupt, killing the threads that upload them and waiting until they have ended, instead of leaving them to upload the rest of the file, which the API bills, after the call has ended
* Raise `Errno::ENOENT` from the uploaders for a `Pathname` of a file that does not exist, instead of `TypeError`, and take a `String` or a `Pathname` wherever an uploader takes a file path
* Send the media category of an upload in lowercase, as the API documents it, rather than as given, since the uploaders accept a category in any case, such as `TWEET_VIDEO`
* Round a fractional `chunk_size_mb` up to a whole number of bytes, rather than read each chunk at a fractional offset, which skipped a byte between some chunks and uploaded a corrupt file
* Take a default value and a block in `X::Uploader::UploadedMedia#fetch`, as `Hash#fetch` does, so `media.fetch("processing_info", nil)` no longer raises `ArgumentError`, and write the media as its response with `as_json` and `to_json`, rather than as a reference to the object
* Read `X::Uploader::UploadedMedia#id` from an identifier held as an Integer, as a Hash built by hand to refer to media uploaded before may hold it, rather than raise `ArgumentError`
* Take the `media_category:` of `X::Uploader::Metadata.add_subtitles` as the uploaders take a category, `tweet_video` or `amplify_video` as a String or a Symbol in any case, as well as the `TweetVideo` and `AmplifyVideo` the subtitles endpoint names them, and raise `ArgumentError` for any other, where a category given as the uploaders take it was sent as given for the endpoint to refuse
* Raise `ArgumentError` from `X::Uploader::Media.upload_binary` for the `amplify_video` category, which the API takes in chunks alone, before a request it would refuse; `upload` uploads such a file in chunks
* Raise `ArgumentError` from the uploaders for an empty file, before any request, where an upload in chunks initialized an upload and finalized it without a chunk, and an upload in a single request sent no media, for the API to refuse either

[1.0.0]: https://github.com/sferik/x-ruby/releases/tag/v1.0.0
