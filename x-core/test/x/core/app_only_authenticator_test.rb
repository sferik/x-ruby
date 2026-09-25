# frozen_string_literal: true

require "base64"
require_relative "../../test_helper"

module X
  class AppOnlyAuthenticatorTest < Minitest::Test
    cover AppOnlyAuthenticator
    cover Core::TokenEndpoint

    def setup
      @authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET)
    end

    def test_initialize
      assert_equal TEST_API_KEY, @authenticator.api_key
      assert_instance_of Connection, @authenticator.connection
    end

    def test_initialize_with_connection
      connection = Connection.new(open_timeout: 5)

      assert_same connection, AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, connection:).connection
    end

    def test_inspect_hides_the_credentials
      assert_equal "#<X::AppOnlyAuthenticator>", @authenticator.inspect
    end

    def test_header_fetches_a_bearer_token
      stub_token_request

      assert_equal({"Authorization" => "Bearer #{TEST_BEARER_TOKEN}"}, @authenticator.header(nil))
    end

    def test_token_request_uses_basic_authentication_and_the_client_credentials_grant
      stub_token_request
      @authenticator.send(:bearer_token)

      assert_requested :post, AppOnlyAuthenticator::TOKEN_URL, body: "grant_type=client_credentials",
        headers: {"Authorization" => "Basic #{Base64.strict_encode64("#{TEST_API_KEY}:#{TEST_API_KEY_SECRET}")}",
                  "Content-Type" => "application/x-www-form-urlencoded", "Accept" => "application/json"}
    end

    def test_token_request_uses_the_connection
      stub_token_request
      requests = []
      connection = Minitest::Mock.new
      connection.expect(:perform, Net::HTTP.post(URI(AppOnlyAuthenticator::TOKEN_URL), "")) { |request:| requests << request }
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, connection:)

      assert_equal TEST_BEARER_TOKEN, authenticator.send(:bearer_token)
      assert_instance_of Net::HTTP::Post, requests.first
      assert_equal "grant_type=client_credentials", requests.first.body
    end

    def test_bearer_token_is_fetched_once
      stub_token_request
      3.times { @authenticator.header(nil) }

      assert_equal TEST_BEARER_TOKEN, @authenticator.send(:bearer_token)
      assert_requested :post, AppOnlyAuthenticator::TOKEN_URL, times: 1
    end

    def test_bearer_token_is_fetched_once_across_threads
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL).to_return do
        sleep 0.05
        {status: 200, body: {access_token: TEST_BEARER_TOKEN}.to_json}
      end
      tokens = Array.new(4) { Thread.new { @authenticator.send(:bearer_token) } }.map(&:value)

      assert_equal [TEST_BEARER_TOKEN] * 4, tokens
      assert_requested :post, AppOnlyAuthenticator::TOKEN_URL, times: 1
    end

    def test_the_bearer_token_is_kept_private
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "given")

      refute_respond_to authenticator, :bearer_token
      assert_equal "given", authenticator.send(:bearer_token)
    end

    def test_a_given_bearer_token_is_not_fetched
      authenticator = AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "given")

      assert_equal({"Authorization" => "Bearer given"}, authenticator.header(nil))
      assert_not_requested :post, AppOnlyAuthenticator::TOKEN_URL
    end

    def test_raises_with_the_error_description
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return(status: 403, body: {error: "invalid_client", error_description: "Unable to verify your credentials"}.to_json)
      error = assert_raises(AuthorizationError) { @authenticator.send(:bearer_token) }

      assert_equal ["Unable to verify your credentials", "invalid_client", 403], [error.message, error.error_code, error.status]
    end

    def test_raises_with_the_error_code_without_a_description
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL).to_return(status: 403, body: {error: "invalid_client"}.to_json)
      error = assert_raises(AuthorizationError) { @authenticator.send(:bearer_token) }

      assert_equal "invalid_client", error.message
    end

    def test_raises_with_the_default_message
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL).to_return(status: 401, body: "Unauthorized")
      error = assert_raises(AuthorizationError) { @authenticator.send(:bearer_token) }

      assert_equal "Bearer token request failed", error.message
    end

    def test_a_token_endpoint_that_fails_to_answer_raises_the_error_of_its_status
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL).to_return({status: 503}, {status: 429})

      assert_raises(ServiceUnavailable) { @authenticator.send(:bearer_token) }
      assert_raises(TooManyRequests) { @authenticator.send(:bearer_token) }
    end

    def test_a_failed_fetch_is_retried
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL).to_return(status: 500, body: "").then
        .to_return(status: 200, body: {access_token: TEST_BEARER_TOKEN}.to_json)
      assert_raises(InternalServerError) { @authenticator.send(:bearer_token) }

      assert_equal TEST_BEARER_TOKEN, @authenticator.send(:bearer_token)
    end

    private

    def stub_token_request
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
    end
  end
end
