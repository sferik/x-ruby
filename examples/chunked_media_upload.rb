require "json"
require "x"
require "x/uploader"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(**x_credentials)
file_path = "path/to/your/media.mp4"
media_category = "tweet_video" # other options include: tweet_image, tweet_gif, dm_image, dm_video, dm_gif, subtitles

media = X::Uploader::Media.chunked_upload(file_path, client:, media_category:)

X::Uploader::Media.await_processing(media, client:) # or X::Uploader::Media.await_processing!(media, client:) to raise an error if fails

post_body = {text: "Posting media from @gem!", media: {media_ids: [media["id"]]}}

post = client.post("tweets", post_body.to_json)

puts post["data"]["id"]
