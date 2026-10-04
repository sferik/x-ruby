# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class TokenReportFailedTest < Minitest::Test
    cover TokenReportFailed

    def test_holds_the_client_and_the_tokens
      client = Client.new
      tokens = OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH", expires_at: nil)
      error = TokenReportFailed.new(client:, tokens:)

      assert_same client, error.client
      assert_same tokens, error.tokens
    end

    def test_holds_nothing_when_given_nothing
      error = TokenReportFailed.new

      assert_nil error.client
      assert_nil error.tokens
    end

    def test_says_the_tokens_were_not_stored
      assert_equal "The code was exchanged for tokens, but save_tokens raised for them", TokenReportFailed.new.message
    end

    def test_takes_a_message_of_its_own
      assert_equal "Not stored", TokenReportFailed.new("Not stored").message
    end

    # An error whose message is not what to_s answers, as an error that builds its message may be
    class StorageDown < StandardError
      def message = "connection refused"
    end

    def test_ends_the_message_with_that_of_its_cause
      error = assert_raises(TokenReportFailed) do
        raise StorageDown
      rescue
        raise TokenReportFailed, "Not stored"
      end

      assert_equal "Not stored: connection refused", error.message
    end

    def test_is_an_error_of_the_gems
      assert_operator TokenReportFailed, :<, Error
    end
  end
end
