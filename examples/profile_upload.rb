require "x"
require "x/account_uploader"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(**x_credentials)

# Update profile image (avatar)
# Supported formats: GIF, JPG, JPEG, PNG
# Image should be under 700 KB
profile_image_path = "path/to/your/avatar.png"

user = X::AccountUploader.update_profile_image(client:, file_path: profile_image_path)
puts "Profile image updated for @#{user["screen_name"]}"

# Update profile banner
# Recommended dimensions: 1500x500 pixels
banner_path = "path/to/your/banner.png"

X::AccountUploader.update_profile_banner(client:, file_path: banner_path)
puts "Profile banner updated successfully"

# Update profile banner with custom dimensions and offset
X::AccountUploader.update_profile_banner(
  client:,
  file_path: banner_path,
  width: 1500,
  height: 500,
  offset_left: 0,
  offset_top: 0
)
puts "Profile banner updated with custom dimensions"
