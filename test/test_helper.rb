# frozen_string_literal: true

require "simplecov"

SimpleCov.start "strict" do
  # x-core, x-uploads, x-streams, and x-resources measure their own coverage in their own suites
  skip %r{\A/?x-(core|uploads|streams|resources)/}
end

require "minitest/autorun"
require "webmock/minitest"
require "x"

TEST_BEARER_TOKEN = "TEST_BEARER_TOKEN"
