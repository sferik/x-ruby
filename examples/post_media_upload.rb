require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(**x_credentials)
file_path = "path/to/your/media.jpg"

# The media category is inferred from the file: an image, an animated GIF, a video, which is uploaded in chunks and
# processed, or subtitles. Pass media_category: to choose another, such as dm_image.
media = X::Uploader::Media.upload(file_path, client:, alt_text: "Describe the image for people who cannot see it")

post = client.create_post("Posting media from @gem!", media_ids: [media])

puts post.id
