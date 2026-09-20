# frozen_string_literal: true

require "x"

# The filtered stream and its rules take app-only authentication. A client with OAuth 1.0a credentials can use
# client.app_only instead of a bearer token.
client = X::Client.new(bearer_token: "INSERT YOUR BEARER TOKEN HERE")

# View existing rules
rules = client.get("tweets/search/stream/rules")
puts "Existing rules: #{rules}"

# Delete all existing rules (if any)
if rules["data"]&.any?
  ids = rules["data"].map { |rule| rule["id"] }
  client.post("tweets/search/stream/rules", {delete: {ids:}})
  puts "Deleted #{ids.size} rule(s)"
end

# Add new rules
new_rules = {add: [
  {value: "ruby lang", tag: "ruby"},
  {value: "#opensource", tag: "opensource"}
]}
result = client.post("tweets/search/stream/rules", new_rules)
puts "Added rules: #{result}"

# Connect to the filtered stream, which reconnects when X drops it
puts "Streaming..."
client.streaming.stream("tweets/search/stream", params: {"post.fields": "created_at", expansions: "author_id"}) do |post|
  author = post.dig("includes", "users")&.first
  puts "@#{author&.fetch("username")}: #{post["data"]["text"]}"
end
