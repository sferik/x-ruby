# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A token endpoint that answers with no body, or with a token that cannot be read as the tokens a client holds, raises
  # InvalidResponse, an X::Error, before a client takes any of it
  class TokenEndpointUnreadableTest < Minitest::Test
    cover Core.const_get(:TokenEndpoint)

    TOKEN_URL = OAUTH2_TOKEN_URL
    TOKEN = {"token_type" => "bearer", "access_token" => "issued", "refresh_token" => "next", "expires_in" => 7200, "scope" => "tweet.read"}.freeze

    def setup
      @authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
    end

    def test_a_response_without_a_body_holds_no_json_object
      refute Core.const_get(:TokenEndpoint).__send__(:json_object?, nil)
    end

    def test_a_token_that_cannot_be_read_raises_invalid_response_and_is_not_taken
      [{"refresh_token" => true}, {"refresh_token" => ""}, {"scope" => "a\"b"}, {"access_token" => "a\nb"}, {"access_token" => " "}].each do |unreadable|
        error = refusing(TOKEN.merge(unreadable))

        assert_equal "POST /2/oauth2/token: The token endpoint answered with a token that cannot be read", error.message
        assert_equal [200, TOKEN.merge(unreadable).to_json], [error.status, error.body]
        assert_equal TEST_REFRESH_TOKEN, @authenticator.__send__(:refresh_token)
      end
    end

    def test_a_token_that_can_be_read_is_taken
      stub_request(:post, TOKEN_URL).to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: TOKEN.to_json)
      @authenticator.refresh!

      assert_equal "next", @authenticator.__send__(:refresh_token)
    end

    private

    # Refresh against a token endpoint that answers with a token, and return the InvalidResponse it raises
    def refusing(token)
      stub_request(:post, TOKEN_URL).to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: token.to_json)
      assert_raises(InvalidResponse, token.inspect) { @authenticator.refresh! }
    end
  end
end
