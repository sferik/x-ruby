$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant")
  require "simplecov"

  SimpleCov.start "strict"
end

require "minitest/autorun"
require "minitest/mock"
require "mutant/minitest/coverage"
require "webmock/minitest"
require "x/media"

TEST_API_KEY = "TEST_API_KEY".freeze
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET".freeze
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN".freeze
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET".freeze
TEST_MEDIA_ID = "TEST_MEDIA_ID".freeze

def test_oauth_credentials
  {
    api_key: TEST_API_KEY,
    api_key_secret: TEST_API_KEY_SECRET,
    access_token: TEST_ACCESS_TOKEN,
    access_token_secret: TEST_ACCESS_TOKEN_SECRET
  }
end
