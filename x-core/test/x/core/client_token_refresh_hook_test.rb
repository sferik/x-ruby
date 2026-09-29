# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientTokenRefreshHookTest < Minitest::Test
    cover_client
    cover OAuth2Authenticator
    cover Core::OAuth2Refresh
    cover Core::RefreshReporter

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
      @refreshed = []
    end

    def test_an_authenticator_holds_no_callable_of_its_own
      refute_respond_to Client.new(**test_oauth2_credentials, on_token_refresh: ->(_) {}).authenticator, :on_token_refresh
    end

    def test_a_refresh_by_the_authenticator_of_a_client_reaches_the_hook_of_the_client
      client = Client.new(**test_oauth2_credentials, on_token_refresh: ->(auth) { @refreshed << auth.access_token })
      client.authenticator.refresh!

      assert_equal ["NEW_ACCESS_TOKEN"], @refreshed
    end

    def test_an_authenticator_that_reports_to_nothing_refreshes
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)

      assert_equal "NEW_REFRESH_TOKEN", authenticator.refresh!.refresh_token
    end

    def test_an_authenticator_passes_a_refresh_to_each_callable_it_reports_to_in_order
      oauth2_authenticator_reporting_to(->(_) { @refreshed << :first }, ->(tokens) { @refreshed << tokens.refresh_token }).refresh!

      assert_equal [:first, "NEW_REFRESH_TOKEN"], @refreshed
    end

    def test_what_an_authenticator_reports_to_is_private
      refute_respond_to OAuth2Authenticator.new(**test_oauth2_credentials), :report_refreshes_to
    end
  end
end
