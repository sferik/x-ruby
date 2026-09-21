# frozen_string_literal: true

require "x"

# The filtered stream and its rules take app-only authentication, which a client built from a bearer token, or from
# an API key and secret, has. A client that signs with OAuth 1.0a fetches one for itself.
client = X::Client.new(bearer_token: "INSERT YOUR BEARER TOKEN HERE")
streaming = client.streaming

# View existing rules
rules = streaming.stream_rules
puts "Existing rules: #{rules}"

# Delete all existing rules (if any)
deleted = streaming.delete_stream_rules(rules)
puts "Deleted #{deleted} rule(s)"

# Add new rules, each a value to match and the tag to label it with
added = streaming.add_stream_rules([{value: "ruby lang", tag: "ruby"}, {value: "#opensource", tag: "opensource"}])
puts "Added rules: #{added}"

# Connect to the filtered stream, which reconnects when X drops it, until the block stops it
puts "Streaming..."
streaming.stream("tweets/search/stream", params: {"post.fields": "created_at", expansions: "author_id"}) do |post|
  author = post.dig("includes", "users")&.first
  puts "@#{author&.fetch("username")}: #{post["data"]["text"]}"
end
