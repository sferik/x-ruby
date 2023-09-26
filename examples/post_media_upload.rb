require "x"
require "mime/types" # requires mime-types gem

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

upload_client = X::Client.new(base_url: "https://upload.twitter.com/1.1/", **x_credentials)

file_path = "path/to/your/image.jpg"
boundary = "AaB03x"

post_body = "--#{boundary}\r\n" \
            "Content-Disposition: form-data; name=\"media\"; filename=\"#{File.basename(file_path)}\"\r\n" \
            "Content-Type: #{MIME::Types.type_for(file_path).first.content_type}\r\n\r\n" \
            "File.read(file_path)\r\n" \
            "--#{boundary}--\r\n"

upload_client.content_type = "multipart/form-data, boundary=#{boundary}"
upload_client.post("media/upload.json?media_category=tweet_image", post_body)
