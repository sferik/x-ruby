# frozen_string_literal: true

require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

# Wait for a rate limit to reset, up to 15 minutes, and retry, up to three times in a row
client = X::Client.new(**x_credentials, max_rate_limit_retries: 3)
user = client.find_user("sferik")

# Each page requests 1,000 followers, the maximum. Pages are fetched lazily and cached.
# With prefetch, the next page is fetched in the background while the current one is printed.
followers = user.followers.prefetch
followers.each { |follower| puts "#{follower.username}: #{follower.followers_count} followers" }

# Iterating again uses the cached pages, so this makes no requests
puts followers.to_a.size

# Count the followers the profile reports, without paging through them
puts user.followers.published_count

# Posts reference their authors. Every reference to the same user in one page is the same object.
user.posts.first(10).each do |post|
  puts "#{post.author.username}: #{post.text}"
end
