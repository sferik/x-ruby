# frozen_string_literal: true

require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

# A large video uploads in many chunks, each a request a rate limit can refuse, so the client waits a rate limit out
# rather than fail the upload
client = X::Client.new(**x_credentials, max_rate_limit_retries: 3)
file_path = "path/to/your/media.mp4"

# client.upload_media uploads a video in chunks of 4 MB and waits for it to be processed. The steps it takes can also
# be run one at a time, to choose the media category, the size of each chunk, and how many are sent at once.
media_category = "tweet_video" # or amplify_video or dm_video: a GIF or subtitles category refuses an MP4 video
media = X::Uploader::MediaUpload.chunked_upload(file_path, client:, media_category:, chunk_size: 5 * 1024 * 1024, concurrency: 2)

# Wait up to five minutes, raising X::MediaProcessingFailed if processing fails
client.await_media_processing!(media, processing_timeout: 300)

post = client.create_post("Posting media from @gem!", media_ids: [media])

puts post.id
