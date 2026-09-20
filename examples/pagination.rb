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

# Page through raw JSON by passing each page's next_token as the pagination_token of the next request
user_id = client.get("users/by/username/sferik").dig("data", "id")
params = {max_results: 1000, "user.fields": "id"}
follower_ids = []

loop do
  response = client.get("users/#{user_id}/followers", params:)
  follower_ids.concat(Array(response["data"]).map { |follower| follower["id"] })
  next_token = response.dig("meta", "next_token") or break
  params = params.merge(pagination_token: next_token)
end

puts follower_ids.size

# A cursor does the same, requesting nothing but identifiers
puts client.find_user("sferik").followers.ids.size
