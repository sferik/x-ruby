require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(**x_credentials)
user = client.find_user("sferik")

# Each page requests 1,000 followers, the maximum. Pages are fetched lazily and cached.
# With prefetch, the next page is fetched in the background while the current one is printed.
followers = user.followers.prefetch

begin
  followers.each { |follower| puts "#{follower.username}: #{follower.followers_count} followers" }
rescue X::TooManyRequests => e
  # NOTE: Your process could go to sleep for up to 15 minutes but if you
  # retry any sooner, it will almost certainly fail with the same exception.
  # Retrying replays the cached pages without requesting them again.
  sleep e.retry_after
  retry
end

# Iterating again uses the cached pages, so this makes no requests
puts followers.count

# Start over with fresh data
puts followers.refresh.count

# Posts reference their authors. Every reference to the same user in one page is the same object.
user.posts.first(10).each do |post|
  puts "#{post.author.username}: #{post.text}"
end
