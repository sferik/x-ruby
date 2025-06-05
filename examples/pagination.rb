require "x"

x_credentials = {
  api_key: "INSERT YOUR X API KEY HERE",
  api_key_secret: "INSERT YOUR X API KEY SECRET HERE",
  access_token: "INSERT YOUR X ACCESS TOKEN HERE",
  access_token_secret: "INSERT YOUR X ACCESS TOKEN SECRET HERE"
}

client = X::Client.new(base_url: "https://api.twitter.com/1.1/", **x_credentials)

screen_name = "sferik"
count = 5000
cursor = -1
follower_ids = []

loop do
  response = client.get("followers/ids.json?screen_name=#{screen_name}&count=#{count}&cursor=#{cursor}")
  follower_ids.concat(response["ids"])
  cursor = response["next_cursor"]
  break if cursor.zero?
rescue X::TooManyRequests => e
  # NOTE: Your process could go to sleep for up to 15 minutes but if you
  # retry any sooner, it will almost certainly fail with the same exception.
  sleep e.retry_after
  retry
end
