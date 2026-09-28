# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An authenticator that makes token requests makes them over the connection of the first client that takes it
  class AuthenticatorTokenConnectionTest < Minitest::Test
    cover AppOnlyAuthenticator
    cover OAuth2Authenticator

    def authenticators
      [AppOnlyAuthenticator.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET), OAuth2Authenticator.new(**test_oauth2_credentials)]
    end

    def test_the_first_connection_an_authenticator_is_given_is_kept
      authenticators.each do |authenticator|
        first = Core::Connection.new
        authenticator.__send__(:token_requests_over, first)

        assert_same authenticator, authenticator.__send__(:token_requests_over, Core::Connection.new)
        assert_same first, authenticator.__send__(:connection)
      end
    end

    def test_a_connection_is_taken_under_the_lock_a_token_request_holds
      authenticators.each do |authenticator|
        connection = Core::Connection.new
        taking(authenticator, connection).join

        assert_same connection, authenticator.__send__(:connection)
      end
    end

    private

    # Start taking a connection while the lock of a token request is held, and check that it waits for the lock
    def taking(authenticator, connection)
      authenticator.instance_variable_get(:@mutex).synchronize do
        Thread.new { authenticator.__send__(:token_requests_over, connection) }.tap do |thread|
          Thread.pass until thread.status.eql?("sleep")

          refute_same connection, authenticator.__send__(:connection)
        end
      end
    end
  end
end
