require "x"
require "x/media_uploader"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(**x_credentials)
file_path = "path/to/your/media.jpg"
media_category = "tweet_image" # other options include: tweet_video, tweet_gif, dm_image, dm_video, dm_gif, subtitles

media = X::MediaUploader.upload(client: client, file_path: file_path, media_category: media_category)

tweet_body = {text: "Posting media from @gem!", media: {media_ids: [media["media_id_string"]]}}

tweet = client.post("tweets", tweet_body.to_json)

puts tweet["data"]["id"]
