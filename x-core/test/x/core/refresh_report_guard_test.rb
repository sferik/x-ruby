# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The save_tokens of a refresh runs inside the guard a gem extending a client sets for the fiber, and outside any
  # when none is set
  class RefreshReportGuardTest < Minitest::Test
    cover Core.const_get(:RefreshReporter)

    GUARD = :x_core_refresh_report_guard

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
    end

    def test_save_tokens_runs_inside_the_guard_of_the_fiber
      events = []
      authenticator = oauth2_authenticator_reporting_to(->(tokens) { events << tokens.refresh_token })
      Thread.current[GUARD] = ->(&block) { events << :before && block.call.tap { events << :after } }
      authenticator.refresh!

      assert_equal [:before, "NEW_REFRESH_TOKEN", :after], events
    ensure
      Thread.current[GUARD] = nil
    end

    def test_save_tokens_runs_unguarded_when_the_fiber_has_no_guard
      saved = []
      oauth2_authenticator_reporting_to(->(tokens) { saved << tokens.refresh_token }).refresh!

      assert_equal ["NEW_REFRESH_TOKEN"], saved
    end
  end
end
