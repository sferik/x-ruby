# frozen_string_literal: true

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

TEST_API_KEY = "TEST_API_KEY"
TEST_API_KEY_SECRET = "TEST_API_KEY_SECRET"
TEST_ACCESS_TOKEN = "TEST_ACCESS_TOKEN"
TEST_ACCESS_TOKEN_SECRET = "TEST_ACCESS_TOKEN_SECRET"
TEST_MEDIA_ID = "1880028106020515840"

# The module, private to MediaUpload, that infers how media uploads
def inference = X::Uploader::MediaUpload.const_get(:Inference)

def test_oauth_credentials
  {
    api_key: TEST_API_KEY,
    api_key_secret: TEST_API_KEY_SECRET,
    access_token: TEST_ACCESS_TOKEN,
    access_token_secret: TEST_ACCESS_TOKEN_SECRET
  }
end

# Run a block on a monotonic clock that stands still but for the sleeps of MediaUpload, which pass at once and are
# added to the waits given, and for the seconds advance_clock passes, as a request that takes them does. It starts
# at no time in particular, as a monotonic clock does, so a deadline counted from zero would be wrong.
def on_fake_clock(waits = [], &)
  @fake_clock = 1000
  Process.stub(:clock_gettime, ->(clock) { clock.eql?(Process::CLOCK_MONOTONIC) ? @fake_clock : raise(ArgumentError, "not the monotonic clock") }) do
    X::Uploader::MediaUpload.stub(:sleep, ->(seconds) { (waits << seconds) && (@fake_clock += seconds) }, &)
  end
end

# Pass seconds on the clock of on_fake_clock, as a request that takes them does
def advance_clock(seconds) = @fake_clock += seconds
