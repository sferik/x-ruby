require "x"
require "mime/types" # requires mime-types gem

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

upload_client = X::Client.new(base_url: "https://upload.twitter.com/1.1/", **x_credentials)

file_path = "path/to/your/media.mp4"
file_name = File.basename(file_path)
media_type = MIME::Types.type_for(file_path).first.content_type
total_bytes = File.size(file_path)
media_category = "tweet_video" # other options include: tweet_image, tweet_gif, dm_image, dm_video, dm_gif, subtitles
init_query_string = "command=INIT&media_type=#{media_type}&media_category=#{media_category}&total_bytes=#{total_bytes}"

media = upload_client.post("media/upload.json?#{init_query_string}")

boundary = "AaB03x"
upload_body = "--#{boundary}\r\n" \
              "Content-Disposition: form-data; name=\"media\"; filename=\"#{file_name}\"\r\n" \
              "Content-Type: #{media_type}\r\n\r\n" \
              "#{File.read(file_path)}\r\n" \
              "--#{boundary}--\r\n"

upload_client.content_type = "multipart/form-data, boundary=#{boundary}"
upload_client.post("media/upload.json?command=APPEND&media_id=#{media["media_id"]}&segment_index=0", upload_body)

media = upload_client.post("media/upload.json?command=FINALIZE&media_id=#{media["media_id"]}")

loop do
  status = upload_client.get("media/upload.json?command=STATUS&media_id=#{media["media_id"]}")
  break if status["processing_info"]["state"] == "succeeded"

  sleep status["processing_info"]["check_after_secs"].to_i
end

tweet_client = X::Client.new(**x_credentials)

tweet_body = {text: "Posting media from @gem!", media: {media_ids: [media["media_id_string"]]}}

tweet = tweet_client.post("tweets", tweet_body.to_json)

puts tweet["data"]["id"]
