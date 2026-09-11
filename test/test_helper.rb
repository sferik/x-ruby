require "simplecov"

SimpleCov.start "strict" do
  # x-core and x-objects measure their own coverage in their own suites
  skip %r{\A/?x-(core|objects)/}
end

require "minitest/autorun"
require "webmock/minitest"
require "x"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN".freeze
