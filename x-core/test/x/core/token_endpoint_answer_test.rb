# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A token endpoint that answers with a token or a refusal is read as OAuth 2.0 answers, and any other response, such
  # as the page of a proxy, firewall, or captive portal, raises the error of its status rather than AuthorizationError,
  # which tells a caller to ask the user to authorize the app again
  class TokenEndpointAnswerTest < Minitest::Test
    cover Core.const_get(:TokenEndpoint)

    TOKEN_URL = OAUTH2_TOKEN_URL
    PAGE = {headers: {"Content-Type" => "text/html"}, body: "<html><body>Sign in to the network</body></html>"}.freeze

    def setup
      @authenticator = OAuth2Authenticator.new(**test_oauth2_credentials)
    end

    def refused(status, body)
      stub_request(:post, TOKEN_URL).to_return(status:, body:)
      assert_raises(AuthorizationError) { @authenticator.refresh! }
    end

    def test_a_successful_page_that_is_not_json_raises_invalid_response_holding_it
      stub_request(:post, TOKEN_URL).to_return(status: 200, **PAGE)
      error = assert_raises(InvalidResponse) { @authenticator.refresh! }

      assert_equal [200, PAGE.fetch(:body), :post, URI(TOKEN_URL)], [error.status, error.body, error.http_method, error.uri]
      assert_equal "text/html", error.headers.fetch("content-type")
      assert_equal TEST_REFRESH_TOKEN, @authenticator.__send__(:refresh_token)
    end

    def test_a_successful_response_of_json_that_is_not_an_object_raises_invalid_response
      stub_request(:post, TOKEN_URL).to_return(status: 200, body: "[]")

      assert_raises(InvalidResponse) { @authenticator.refresh! }
    end

    def test_a_successful_response_of_json_without_a_token_is_refused
      assert_equal ["token response has no access_token", 200], refused(200, "{}").then { [it.message, it.status] }
    end

    def test_a_forbidden_page_that_is_not_json_raises_forbidden
      stub_request(:post, TOKEN_URL).to_return(status: 403, **PAGE)
      error = assert_raises(Forbidden) { @authenticator.refresh! }

      assert_equal [403, :post, URI(TOKEN_URL)], [error.status, error.http_method, error.uri]
    end

    def test_a_redirect_raises_the_error_of_its_status
      stub_request(:post, TOKEN_URL).to_return(status: 302, headers: {"Location" => "https://portal.example.com/"})

      assert_equal 302, assert_raises(HTTPError) { @authenticator.refresh! }.status
    end

    def test_a_bad_request_or_unauthorized_is_a_refusal_whatever_its_body
      assert_equal 400, refused(400, PAGE.fetch(:body)).status
      assert_equal 401, refused(401, "").status
    end

    def test_another_client_error_of_json_is_a_refusal
      error = refused(403, {error: "invalid_client", error_description: "Unable to verify your credentials"}.to_json)

      assert_equal ["Unable to verify your credentials", "invalid_client", 403], [error.message, error.error_code, error.status]
    end

    def test_a_client_error_of_json_that_is_not_an_object_raises_the_error_of_its_status
      stub_request(:post, TOKEN_URL).to_return(status: 404, body: "[]")

      assert_raises(NotFound) { @authenticator.refresh! }
    end

    def test_too_many_requests_of_json_raises_too_many_requests
      stub_request(:post, TOKEN_URL).to_return(status: 429, body: {error: "rate_limited"}.to_json)

      assert_raises(TooManyRequests) { @authenticator.refresh! }
    end

    def test_the_bearer_token_of_an_app_raises_the_error_of_a_page_that_is_not_json
      stub_request(:post, APP_ONLY_TOKEN_URL).to_return(status: 403, **PAGE)

      assert_raises(Forbidden) { AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET).__send__(:bearer_token) }
    end
  end
end
