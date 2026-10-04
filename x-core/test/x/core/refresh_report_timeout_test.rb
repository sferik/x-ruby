# frozen_string_literal: true

require "timeout"
require_relative "../../test_helper"

module X
  # A Timeout::Error raised as save_tokens runs, whether by a timeout of its store or by Timeout.timeout around the
  # request, fails save_tokens as any error does, so the error still holds the tokens it was passed
  class RefreshReportTimeoutTest < Minitest::Test
    cover Core.const_get(:RefreshReporter)

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
    end

    def test_a_timeout_of_the_store_of_save_tokens_holds_the_tokens_and_the_rest_are_still_passed_them
      saved = []
      authenticator = oauth2_authenticator_reporting_to(->(_tokens) { Timeout.timeout(0.01) { sleep 1 } }, ->(tokens) { saved << tokens })
      error = assert_raises(TokenReportFailed) { authenticator.refresh! }

      assert_kind_of Timeout::Error, error.cause
      assert_equal ["NEW_REFRESH_TOKEN"] * 2, [error.tokens, *saved].map(&:refresh_token)
    end

    def test_a_timeout_raised_around_the_request_as_save_tokens_runs_holds_the_tokens
      authenticator = oauth2_authenticator_reporting_to(->(_tokens) { sleep 1 })
      error = assert_raises(TokenReportFailed) { Timeout.timeout(0.05, Timeout::Error) { authenticator.refresh! } }

      assert_equal "NEW_REFRESH_TOKEN", error.tokens.refresh_token
    end

    def test_a_timeout_raised_without_a_class_around_the_request_as_save_tokens_runs_is_raised_as_it_is
      authenticator = oauth2_authenticator_reporting_to(->(_tokens) { sleep 1 })

      assert_instance_of Timeout::Error, assert_raises(Timeout::Error) { Timeout.timeout(0.05) { authenticator.refresh! } }
    end
  end
end
