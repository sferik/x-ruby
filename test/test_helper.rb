$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.end_with?("mutant")
  require "simplecov"

  SimpleCov.start do
    add_filter "test"
    minimum_coverage(100)
  end
end

require "minitest/autorun"
require "mutant/minitest/coverage"
require "webmock/minitest"
require "x"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN".freeze
TEST_API_KEY = "TEST_API_KEY".freeze
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET".freeze
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN".freeze
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET".freeze
TEST_OAUTH_NONCE = "TEST_OAUTH_NONCE".freeze
TEST_OAUTH_TIMESTAMP = Time.utc(1983, 11, 24).to_i.to_s
TEST_MEDIA_ID = "TEST_MEDIA_ID".freeze

def test_oauth_credentials
  {
    api_key: TEST_API_KEY,
    api_key_secret: TEST_API_KEY_SECRET,
    access_token: TEST_ACCESS_TOKEN,
    access_token_secret: TEST_ACCESS_TOKEN_SECRET
  }
end

def test_oauth_params
  {
    "oauth_consumer_key" => TEST_API_KEY,
    "oauth_nonce" => TEST_OAUTH_NONCE,
    "oauth_signature_method" => X::OAuthAuthenticator::OAUTH_SIGNATURE_METHOD,
    "oauth_timestamp" => TEST_OAUTH_TIMESTAMP,
    "oauth_token" => TEST_ACCESS_TOKEN,
    "oauth_version" => X::OAuthAuthenticator::OAUTH_VERSION
  }
end
