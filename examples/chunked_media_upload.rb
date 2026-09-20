# frozen_string_literal: true

require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(**x_credentials)
file_path = "path/to/your/media.mp4"

# client.upload_media uploads a video in chunks and waits for it to be processed. The steps it takes can also
# be run one at a time, to choose the media category, the size of each chunk, and how many are sent at once.
media_category = "tweet_video" # other options include: amplify_video, dm_video, tweet_gif, dm_gif, and subtitles
media = X::Uploader::MediaUpload.chunked_upload(file_path, client:, media_category:, chunk_size_mb: 4, concurrency: 2)

# Wait up to five minutes, raising X::MediaProcessingFailed if processing fails
client.await_media_processing!(media, processing_timeout: 300)

post = client.create_post("Posting media from @gem!", media_ids: [media])

puts post.id
