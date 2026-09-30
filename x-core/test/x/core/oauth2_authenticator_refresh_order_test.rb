# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The order in which an authenticator reports its refreshes, which is the order a store must keep them in
  class OAuth2AuthenticatorRefreshOrderTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)
    cover Core.const_get(:RefreshReporter)

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "FIRST_ACCESS_TOKEN", refresh_token: "FIRST_REFRESH_TOKEN"}.to_json)
        .then.to_return(status: 200, body: {access_token: "SECOND_ACCESS_TOKEN", refresh_token: "SECOND_REFRESH_TOKEN"}.to_json)
      @stored = []
    end

    def test_a_refresh_another_replaced_before_it_was_reported_is_not_reported
      authenticator = oauth2_authenticator_reporting_to(->(tokens) { @stored << tokens.refresh_token })
      first = authenticator.__send__(:refresh, authenticator.send(:connection))
      second = authenticator.__send__(:refresh, authenticator.send(:connection))
      authenticator.__send__(:report_refresh, second, nil)
      authenticator.__send__(:report_refresh, first, nil)

      assert_equal ["SECOND_REFRESH_TOKEN"], @stored
    end

    def test_a_refresh_waits_to_be_reported_until_the_one_before_it_has_been
      authenticator = oauth2_authenticator_reporting_to(storing_the_first_slowly)
      first = Thread.new { authenticator.refresh! }
      @storing.pop
      second = Thread.new { authenticator.refresh! }
      Thread.pass until second.status.eql?("sleep")

      assert_empty @stored
      @stored_first << :done
      [first, second].each(&:join)

      assert_equal %w[FIRST_REFRESH_TOKEN SECOND_REFRESH_TOKEN], @stored
    end

    def test_a_hook_that_raises_keeps_no_other_from_the_tokens
      authenticator = oauth2_authenticator_reporting_to(->(_) { raise ArgumentError, "store is down" },
        ->(tokens) { @stored << tokens.refresh_token }, ->(_) { raise KeyError })
      error = assert_raises(TokenReportFailed) { authenticator.refresh! }

      assert_equal [ArgumentError, "store is down", ["FIRST_REFRESH_TOKEN"]], [error.cause.class, error.cause.message, @stored]
    end

    private

    # A hook that stores the tokens of the first refresh only once told to, saying when it has begun to
    def storing_the_first_slowly
      @storing = Queue.new
      @stored_first = Queue.new
      lambda do |tokens|
        @storing << tokens.refresh_token
        @stored_first.pop if tokens.refresh_token.eql?("FIRST_REFRESH_TOKEN")
        @stored << tokens.refresh_token
      end
    end
  end
end
