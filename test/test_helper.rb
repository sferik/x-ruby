$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "simplecov"

SimpleCov.start do
  add_filter "test"
  minimum_coverage(100)
end

require "x"
require "minitest/autorun"
require "webmock/minitest"

def client_bearer
  X::Client.new(bearer_token: "TEST_BEARER_TOKEN")
end

def client_oauth
  api_key = "TEST_API_KEY"
  api_key_secret = "TEST_API_KEY_SECRET"
  access_token = "TEST_ACCESS_TOKEN"
  access_token_secret = "TEST_ACCESS_TOKEN_SECRET"

  X::Client.new(api_key: api_key, api_key_secret: api_key_secret, access_token: access_token,
                access_token_secret: access_token_secret)
end

def stub_bearer_request(method, endpoint, status)
  stub_request(method, "https://api.twitter.com/2/#{endpoint}")
    .with(headers: { "Authorization" => /Bearer/ })
    .to_return(status: status, body: {}.to_json)
end

def stub_oauth_request(method, endpoint, status)
  stub_request(method, "https://api.twitter.com/2/#{endpoint}")
    .with(headers: { "Authorization" => /OAuth/ })
    .to_return(status: status, body: {}.to_json)
end
