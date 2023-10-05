$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "simplecov"

SimpleCov.start do
  add_filter "test"
  minimum_coverage(100)
end

require "minitest/autorun"
require "json"
require "net/http"
require "timecop"
require "webmock/minitest"
require "x"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN".freeze
TEST_API_KEY = "TEST_API_KEY".freeze
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET".freeze
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN".freeze
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET".freeze

def client
  X::Client.new(**oauth_credentials)
end

def oauth_credentials
  {
    api_key: TEST_API_KEY,
    api_key_secret: TEST_API_KEY_SECRET,
    access_token: TEST_ACCESS_TOKEN,
    access_token_secret: TEST_ACCESS_TOKEN_SECRET
  }
end
