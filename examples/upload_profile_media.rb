require "base64"
require "uri"
require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(base_url: "https://api.twitter.com/1.1/", **x_credentials)

avatar_path = "path/to/avatar.jpg"
avatar_data = Base64.encode64(File.binread(avatar_path))
avatar_body = URI.encode_www_form(image: avatar_data)
client.post("account/update_profile_image.json", avatar_body, headers: {"Content-Type" => "application/x-www-form-urlencoded"})

banner_path = "path/to/banner.jpg"
banner_data = Base64.encode64(File.binread(banner_path))
banner_body = URI.encode_www_form(banner: banner_data)
client.post("account/update_profile_banner.json", banner_body, headers: {"Content-Type" => "application/x-www-form-urlencoded"})
