require "json"
require "x"

client = X::Client.new(bearer_token: "INSERT YOUR BEARER TOKEN HERE")

# View existing rules
rules = client.get("tweets/search/stream/rules")
puts "Existing rules: #{rules}"

# Delete all existing rules (if any)
if rules["data"]&.any?
  ids = rules["data"].map { |rule| rule["id"] }
  client.post("tweets/search/stream/rules", {delete: {ids: ids}}.to_json)
  puts "Deleted #{ids.size} rule(s)"
end

# Add new rules
new_rules = {add: [
  {value: "ruby lang", tag: "ruby"},
  {value: "#opensource", tag: "opensource"}
]}
result = client.post("tweets/search/stream/rules", new_rules.to_json)
puts "Added rules: #{result}"

# Connect to the filtered stream
puts "Streaming..."
client.stream("tweets/search/stream?tweet.fields=created_at&expansions=author_id") do |tweet|
  puts "@#{tweet["includes"]["users"].first["username"]}: #{tweet["data"]["text"]}"
end
