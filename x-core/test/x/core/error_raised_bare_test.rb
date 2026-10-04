# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An error that takes a message is raised with none, as any exception is, as a test stub may raise it, and is named
  # by its class, naming no request
  class ErrorRaisedBareTest < Minitest::Test
    cover NetworkError
    cover TooManyRedirects
    cover AuthorizationDenied

    URI_OF_REQUEST = URI("https://api.x.com/2/users/me")

    def test_errors_that_take_a_message_are_raised_with_none
      [NetworkError, TooManyRedirects, AuthorizationDenied].each do |error_class|
        error = assert_raises(error_class) { raise error_class }

        assert_equal error_class.name, error.message
      end
    end

    def test_an_error_given_no_message_names_no_request
      [NetworkError, TooManyRedirects].each do |error_class|
        error = error_class.new(http_method: :get, uri: URI_OF_REQUEST)

        assert_equal [error_class.name, :get, URI_OF_REQUEST], [error.message, error.http_method, error.uri]
      end
    end

    def test_an_error_given_a_message_still_names_the_request
      [NetworkError, TooManyRedirects].each do |error_class|
        assert_equal "GET /2/users/me: boom", error_class.new("boom", http_method: :get, uri: URI_OF_REQUEST).message
      end
    end

    def test_an_authorization_denied_given_no_message_holds_no_error_code
      error = AuthorizationDenied.new

      assert_equal ["X::AuthorizationDenied", nil], [error.message, error.error_code]
    end
  end
end
