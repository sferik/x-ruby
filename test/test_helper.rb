$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "simplecov"

SimpleCov.start do
  add_filter "test"
  minimum_coverage(100)
end

require "x"
require "minitest/autorun"
require "webmock/minitest"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN".freeze
TEST_API_KEY = "TEST_API_KEY".freeze
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET".freeze
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN".freeze
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET".freeze

def client_bearer
  X::Client.new(bearer_token: TEST_BEARER_TOKEN)
end

def client_oauth
  X::Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, access_token: TEST_ACCESS_TOKEN,
    access_token_secret: TEST_ACCESS_TOKEN_SECRET)
end

def stub_bearer_request(method, endpoint, status, headers = {})
  headers = {"content-type" => X::ClientDefaults::DEFAULT_CONTENT_TYPE}.merge(headers)
  stub_request(method, "https://api.twitter.com/2/#{endpoint}")
    .with(headers: {"Authorization" => /Bearer/})
    .to_return(status: status, headers: headers, body: {}.to_json)
end

def stub_oauth_request(method, endpoint, status, headers = {})
  headers = {"content-type" => X::ClientDefaults::DEFAULT_CONTENT_TYPE}.merge(headers)
  stub_request(method, "https://api.twitter.com/2/#{endpoint}")
    .with(headers: {"Authorization" => /OAuth/})
    .to_return(status: status, headers: headers, body: {}.to_json)
end
