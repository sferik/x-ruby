# frozen_string_literal: true

require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(**x_credentials)

# Update profile image (avatar)
# Supported formats: GIF, JPEG, PNG, told by the bytes the image begins with, whatever its file is named
# The image must be no larger than 700 KB, or X::InvalidMedia is raised before any request
profile_image_path = "path/to/your/avatar.png"

client.update_profile_image(profile_image_path)
puts "Profile image updated for @#{client.current_user!.username}"

# Update profile banner
# Recommended dimensions: 1500x500 pixels, of no more than 5 MB
banner_path = "path/to/your/banner.png"

client.update_profile_banner(banner_path)
puts "Profile banner updated successfully"

# Update profile banner with custom dimensions and offset
client.update_profile_banner(
  banner_path,
  width: 1500,
  height: 500,
  offset_left: 0,
  offset_top: 0
)
puts "Profile banner updated with custom dimensions"
