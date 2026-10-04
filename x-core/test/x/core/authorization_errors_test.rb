# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # X refusing a token raises AuthorizationError, a ClientError that holds the response of X, and the redirect back
  # from X that says the app was not authorized raises AuthorizationDenied, which holds no response
  class AuthorizationErrorsTest < Minitest::Test
    cover AuthorizationError
    cover AuthorizationDenied

    def test_the_error_code_is_read_from_the_json_of_the_body_whatever_its_content_type
      assert_equal "invalid_grant", AuthorizationError.new(status: 400, body: '{"error":"invalid_grant"}').error_code
    end

    def test_a_body_that_names_no_error_code_has_none
      ["", "Unauthorized", "[]", '{"error":1}', "{}"].each do |body|
        assert_nil AuthorizationError.new(status: 400, body:).error_code, body
      end
      assert_nil AuthorizationError.new(status: 401).error_code
    end

    def test_an_authorization_error_is_raised_as_a_bad_request_of_its_own
      error = assert_raises(ClientError) { raise AuthorizationError, "refused" }

      assert_equal [AuthorizationError, 400, "refused"], [error.class, error.status, error.message]
    end

    def test_an_authorization_denied_holds_its_message_and_error_code
      error = AuthorizationDenied.new("The user denied the request", error_code: "access_denied")

      assert_equal ["The user denied the request", "access_denied"], [error.message, error.error_code]
      assert_nil AuthorizationDenied.new("The state does not match").error_code
    end
  end
end
