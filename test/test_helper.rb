require "simplecov"

SimpleCov.start "strict" do
  # x-core, x-media, and x-objects measure their own coverage in their own suites
  skip %r{\A/?x-(core|media|objects)/}
end

require "minitest/autorun"
require "webmock/minitest"
require "x"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN".freeze
