$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

unless $PROGRAM_NAME.include?("mutant")
  require "simplecov"

  SimpleCov.start "strict"
end

require "minitest/autorun"
require "minitest/mock"
# Mutant is in the bundle of CRuby alone, where the mutant job of CI runs. Without it, the expression a test
# declares it covers is read by nothing, so cover does nothing rather than fail the suite on another engine.
begin
  require "mutant/minitest/coverage"
rescue LoadError
  module Minitest
    class Test
      # Ignore the expression this test covers, which only Mutant reads
      #
      # @param _expression [Object] the expression the test covers
      # @return [void]
      def self.cover(_expression) = nil
    end
  end
end
require "webmock/minitest"
require "x/uploader"

TEST_API_KEY = "TEST_API_KEY".freeze
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET".freeze
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN".freeze
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET".freeze
TEST_MEDIA_ID = "1880028106020515840".freeze

def test_oauth_credentials
  {
    api_key: TEST_API_KEY,
    api_key_secret: TEST_API_KEY_SECRET,
    access_token: TEST_ACCESS_TOKEN,
    access_token_secret: TEST_ACCESS_TOKEN_SECRET
  }
end
