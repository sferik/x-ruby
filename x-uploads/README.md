# x-uploads

Media uploads for the [`x` gem](https://github.com/sferik/x-ruby), built on the HTTP client in [`x-core`](https://github.com/sferik/x-ruby/tree/main/x-core).

* `X::Uploads::MediaUpload` uploads images, GIFs, videos, and subtitles. Videos, subtitles, and a GIF larger than a single request takes are split into chunks that upload in parallel, with retries, and processing can be awaited.
* `X::Uploads::Account` updates the authenticated user's profile image and banner through the v1.1 API, at the host of the base URL of the client it is given.

Installing [`x`](https://rubygems.org/gems/x) installs this gem too.

## Installation

`x-uploads` requires Ruby 3.4 or later.

    bundle add x-uploads

## Usage

```ruby
require "x/uploads"

client = X::Client.new(**x_credentials)

media = X::Uploads::MediaUpload.upload("cat.jpg", client:, alt_text: "A cat asleep on a keyboard")

video = X::Uploads::MediaUpload.chunked_upload("cat.mp4", client:)
X::Uploads::MediaUpload.await_processing!(video, client:)

subtitles = X::Uploads::MediaUpload.upload("cat.srt", client:)
X::Uploads::Metadata.add_subtitles(video, subtitles, "EN", client:, display_name: "English")

X::Uploads::Account.update_profile_image("avatar.png", client:)
```

The `client:` of each uploader is an `X::Client` of `x-core`, which sends the multipart and JSON bodies of an upload, resolves the v1.1 endpoints of the profile uploads against its base URL, and sends a chunk, the finalize, and alt text or subtitles again after a server error, 408, or network error, even a timeout, up to its `max_retries`, unless a `Retry-After` asks for more than a minute, though it sends no other POST again; X bills each alt text or subtitles request, so one whose answer was lost may be billed twice.

An upload takes media as a path, or as an IO open on it. Media given as a `String` or a `Pathname` is read from the file it names, and media given as a `File` or a `Tempfile`, or as `$stdin` redirected from a file, through that IO, from the start of the file, even once the `Tempfile` is unlinked, or from the file it names once it is closed, each a chunk at a time, so media of any size uploads without being held in memory; media given as any other IO, such as a `StringIO`, or `$stdin` reading a pipe, is read to its end and held. Either IO is left at the position it held, when it can seek, so media whose type was inferred can be uploaded next. The media category is inferred from the bytes the media begins with, which name a GIF, PNG, JPEG, BMP, TIFF, WebP, MP4, QuickTime, WebM, MPEG transport stream, or WebVTT file, or else from the extension of the name of its file, so a file named as what it is not, such as a PNG named `.gif`, is uploaded as what it is. A file named as a type every file of which begins with a signature, a GIF, PNG, JPEG, BMP, TIFF, WebP, WebVTT, or MPEG transport stream file, that does not begin with it, such as TypeScript named `.ts`, raises `X::InvalidMediaType` before any request. A String is a path, so one that holds the contents of media, a NUL byte or a line break, raises `ArgumentError` before any request: pass a `StringIO` of the contents instead. Media whose type neither its bytes nor the name of its file names, such as SubRip subtitles held in a `StringIO`, a HEIC photo, a PDF, or a `Tempfile` of any of them, raises `X::InvalidMediaType` before any request unless `media_category:` says what it is.

```ruby
X::Uploads::MediaUpload.upload(Pathname("cat.jpg"), client:)
File.open("cat.mp4", "rb") { |file| X::Uploads::MediaUpload.upload(file, client:) }
X::Uploads::MediaUpload.upload(StringIO.new(png), client:)
X::Uploads::MediaUpload.upload(StringIO.new(srt), client:, media_category: "subtitles")
```

An upload returns an `X::UploadedMedia`, a frozen object that holds the response, or the processing status of media that X processes. It reads `id`, as an Integer, though `media["id"]` is the String the API gave, which must be an `Integer` or a `String` of 1 to 19 digits alone, with no sign, underscore, or whitespace, so `X::UploadedMedia.new` raises `ArgumentError` for any other, `media_id`, the same Integer, as the `X::Media` of `x-resources` reads it, `media_key`, `bytesize`, `expires_after_secs`, the seconds after the upload within which a post can attach it, and `state`, tells `processing?`, until X reports that its processing succeeded or failed, `failed?`, and `ready?`, once its processing has succeeded or for media X does not process, so media in a state X does not document, as one X adds would be, is still processing, and is waited for as pending media is, up to the `processing_timeout:`, while media built from an identifier alone, which holds no response of X to say, is neither processing nor ready, and still reads as the Hash an upload used to return, with `[]`, `fetch`, `dig`, `key?`, `to_h`, and `to_json`. The uploaders take it wherever they take media, as `create_post` of `x-resources` does, and `find_media(media)` of `x-resources` looks up the `X::Media` it became, with its URL and variants.

```ruby
media.id          # => 1880028106020515840
media["id"]       # => "1880028106020515840", the String the API gave, which media.id reads as an Integer
media.ready?      # => true once X reports its processing succeeded, or at once for an image
media.expires_after_secs # => 86400, the seconds after the upload within which a post can attach it
```

`X::Uploads::API` holds the uploads a client is most often asked for, as methods that call the uploaders with the client. The `x` gem includes it into `X::Client`. With `x-core` and `x-uploads` alone, include it yourself:

```ruby
X::Client.include(X::Uploads::API)

media = client.upload_media("cat.jpg", alt_text: "A cat asleep on a keyboard")
video = client.chunked_upload_media("talk.mp4")  # returns once uploaded, before X processes it
client.upload_media(StringIO.new(png))    # media held in memory, whose category its signature names
client.await_media_processing(video)      # returns the status, failed or not, without a request once processing ended
client.await_media_processing!(video)     # raises X::MediaProcessingFailed unless processing succeeded
client.add_alt_text(media, "A cat asleep on a keyboard") # returns the media, an X::UploadedMedia
client.add_subtitles(video, subtitles, "EN", display_name: "English")
client.update_profile_image("avatar.png")
client.update_profile_banner("banner.png", width: 1500, height: 500)
```

A type checker needs the include declared too, as the `sig/x.rbs` of `x` declares it, with `class X::Client` and `include X::Uploads::API` in a signature of your own.

Every method that takes a file takes its path as a `String` or a `Pathname`, or an IO that reads it, such as a `File` or a `StringIO`, which is read from its start; each raises `X::InvalidMedia` for a path to a file that does not exist, before any request, as it does for media that cannot be read, such as an IO whose `read` raises a system error, or a `File` closed while it is read, as by another thread, either of which is its `cause`, and for any media the API would refuse. A `String` is read as a path on the machine the upload runs on, so never pass one a user gave, such as a parameter of a form, which could name any file the process can read, and upload it to X: pass the IO of the file the user uploaded, such as the `tempfile` of a Rack upload, instead. A profile image or banner must begin with the signature of a GIF, a JPEG, or a PNG, whatever its file is named, and a profile image larger than the 700 KB the API takes, or a banner larger than the 5 MB X takes, raises `X::InvalidMedia` before any request. The `width:` and `height:` of the region of a banner to use are positive `Integer`s of pixels, and its `offset_left:` and `offset_top:` `Integer`s of at least 0, or nil, and anything else raises `ArgumentError` before any request. A media category is read in any case, as a `String` or a `Symbol`, and alt text of more than the 1,000 characters the API takes, or of none, raises `ArgumentError` before anything is uploaded. `await_processing` and `await_processing!` take the response of an upload, a media identifier, or anything that answers `media_key`, such as the `X::Media` of a post, as `X::Uploads::Metadata` does, and raise `ArgumentError` for anything else, and for media that holds no identifier, such as nil. `add_alt_text` and `add_subtitles` return the media they describe, the video for `add_subtitles`, as an `X::UploadedMedia`. An image larger than 5 MB, a GIF larger than 15 MB, subtitles larger than 1 MB, and media larger than the 16 GB X takes of any upload raise `X::InvalidMedia` before any request, since X takes no more of them whatever the account, as does media that cannot be read or holds nothing; the size of a video within that depends on the account, so it is left to X. `X::InvalidMedia` is raised for the media, which a user may have given, and `ArgumentError` for a mistake in the arguments of the call, so code that uploads what a user gives rescues the one alone, though an `X::InvalidMedia` whose `cause` is a system error, such as `Errno::EMFILE` or `Errno::EIO`, says the machine could not read the media, not that the media is wrong.

`upload` infers the media category from the file. A GIF with a single frame is an image, because X processes only animated GIFs as GIFs. Videos are MP4, QuickTime, WebM, or MPEG-TS files and subtitles are SubRip (`.srt`) or WebVTT (`.vtt`) files, each uploaded in chunks as the type its bytes, or else its extension, name. Media of a type its `media_category:` does not take, such as an MP4 video uploaded as `tweet_gif` or `subtitles`, or a PNG uploaded as `tweet_video`, raises `X::InvalidMediaType` before any request, rather than be sent as a type it is not; an upload in chunks, by `chunked_upload` or by `upload` of a category that uploads in chunks, such as `tweet_video`, sends the `media_type:` it is given as it is, without these checks, while an upload in a single request sends no type, since the API types the media itself. A video or subtitles category uploads media whose type neither its bytes nor its name names as MP4 or SubRip, which may begin with nothing that names them, and an image category sends it in a single request for the API to type, as it types a HEIC photo, or, uploaded in chunks, as shared media is, as JPEG. An `.m4v` file is MP4. The API documents no media type for AVI or Matroska video, so an `.avi` or `.mkv` file, or media whose name names no type, such as a `StringIO`, that begins with the header of Matroska, raises `X::InvalidMediaType` before any request, unless it begins with the signature of a type the API documents, as a WebM video, which is Matroska and uploads as WebM, does; convert any other to MP4, QuickTime, WebM, or MPEG-TS. No media category takes a 3D model, so a `.glb` or `.usdz` file raises `X::InvalidMediaType` before any request too. Any of these uploads in chunks as the `media_type:` it is given along with a `media_category:`, which together name the type to send for media no rule here types; a `media_type:` alone is not enough, since the category is inferred from the media first.

`X::AltTextFailed`, which an upload raises when it uploaded the media but could not add its alt text, and which holds the `media` it uploaded, `X::ChunkedUploadFailed`, which a chunked upload raises when it initialized the upload but a chunk or its finalize failed, and which holds the `media` it initialized, `X::InvalidMedia`, which a file that does not exist, and media the API would refuse, raise before any request, and which `X::InvalidMediaType` descends from, `X::MediaProcessingCheckFailed`, which an upload raises when it uploaded the media but a check of its processing failed, and which holds the `media` it uploaded too, `X::MediaProcessingFailed` and `X::MediaProcessingTimeout`, which hold the `media` as X last reported its processing, and `X::MissingMediaData`, which a response that succeeded without the media or metadata it should describe raises, and which holds the `problems` the response reported in their place, descend from `X::Uploads::Error`, which descends from `X::Error`, so `rescue X::Uploads::Error` catches the errors x-uploads raises of its own. An `X::TokenReportFailed`, which a request that refreshed the tokens raises when `save_tokens` raised for them, is raised as it is from any request of an upload, a chunk, the finalize, a check of processing, or alt text among them, rather than as the cause of one of these, so `rescue X::TokenReportFailed => e` around an upload stores `e.tokens`, as it does around any other request, though it holds no media. An `X::Error` of a request the API refused, or that got no response, before there was media to hold, such as the `X::BadRequest` of the request that initializes an upload, raises past it, so `rescue X::Error` catches every failure of an upload but an `ArgumentError`, which is not an `X::Error`: that of a mistake in the arguments of a call, and the one a request raises when the client was given no `proxy_url` and the proxy the environment names, in `https_proxy` or `http_proxy`, in either case, cannot be parsed, or is not an `http` or `https` URL with a host, with a message that names the variables read and leaves out the value. The request that initializes an upload, or sends it in a single request, raises that one as it is, and a later request that opens a connection fails with it as the `cause` of the `X::ChunkedUploadFailed`, `X::MediaProcessingCheckFailed`, or `X::AltTextFailed` it raises.

`upload` uploads an image, and a GIF a single request takes, in a single request, which takes no chunks and no media type, so it ignores `chunk_size:`, `concurrency:`, and `media_type:` for them, though a `chunk_size:` or `concurrency:` that is not valid still raises; media given `shared: true` uploads in chunks, and uses all three. `chunked_upload`, and `chunked_upload_media` of a client, upload in chunks whatever the media, and are the way to upload without waiting for X to process it: `upload` waits for the processing of a video or an animated GIF, and they return once the upload is finalized.

A chunked upload sends four chunks at once, `X::Uploads::MediaUpload::DEFAULT_CONCURRENCY`, unless `concurrency:` says otherwise, up to 16, `X::Uploads::MediaUpload::MAX_CONCURRENCY`, since each chunk sent at once holds up to 5 MB and a connection of its own; a concurrency above that raises `ArgumentError` before anything is uploaded. It uploads in chunks of 4 MB, `X::Uploads::MediaUpload::DEFAULT_CHUNK_SIZE`, or of as much more as it takes to upload the file in the 10,000 segments the API numbers, up to the 5 MB X asks a segment to keep to, unless `chunk_size:` says otherwise, in bytes; a chunk size that is not a positive `Integer`, one above the 5,242,880 bytes of 5 MB, and one that would need more segments than that raise `ArgumentError` before anything is uploaded, as a file larger than the 16 GB X takes of an upload raises `X::InvalidMedia`. Each chunk is a request of its own, which a rate limit can refuse, and a client retries a request refused for a rate limit only `max_rate_limit_retries` times, 0 by default, so a chunk refused fails the upload with `X::ChunkedUploadFailed`: upload a large video with a client whose `max_rate_limit_retries` is set, such as `X::Client.new(**x_credentials, max_rate_limit_retries: 3)`, so that a rate limit is waited out, up to its `max_rate_limit_wait`, rather than fail the upload. An exception raised in the thread that uploads, such as a timeout or an interrupt, stops every chunk, so no thread goes on uploading after the call has ended, though a chunk storing the tokens of a refresh with `save_tokens` finishes storing them first, as one reading its bytes from the media finishes reading them, so that the file is closed, and one under way when an exception a `trap` raises lands may finish its upload. Since each chunk is sent from a thread of its own, the client's `on_response` runs on those threads for the response of each chunk, so a hook that reads state kept for the thread that called, such as a Rails `CurrentAttributes` or a logger of its own, reads that of another thread while the chunks upload.

An upload, in chunks or not, takes `additional_owners:`, the identifiers of the users other than the one who uploads it who may use the media, as `Integer`s or `String`s of digits, and `shared: true` or `false`, which says whether the media can be sent in more than one direct message. Media given `shared: true` uploads in chunks, since the single request an image is uploaded in takes no `shared`. Either that is not what the API takes raises `ArgumentError` before anything is uploaded.

The methods of `X::Uploads::MediaUpload`, `X::Uploads::Account`, and `X::Uploads::Metadata` can be called on the module, or on an instance of a class that includes it. Such a class gains the documented public methods and constants alone, the constants being those of `X::Uploads::MediaUpload`, which are its media categories, such as `TWEET_IMAGE`, and `DEFAULT_CHUNK_SIZE`, `DEFAULT_CONCURRENCY`, `DEFAULT_PROCESSING_TIMEOUT`, and `MAX_CONCURRENCY`, so its own methods, whatever their names, cannot change an upload.

## Development

This gem has its own `Gemfile`, `Steepfile`, signatures, test suite, and mutation config. It uses the `x-core` in this repository and does not load `x-resources`:

    bundle install
    bundle exec rake test
    bundle exec rake mutant
    bundle exec rake steep
    bundle exec rake yardstick

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
