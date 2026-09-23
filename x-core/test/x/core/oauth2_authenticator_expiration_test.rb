# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class OAuth2AuthenticatorExpirationTest < Minitest::Test
    cover OAuth2Authenticator

    def setup
      @expires_at = Time.now + 60
      @authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: @expires_at)
    end

    def test_the_expiration_time_and_the_refresh_of_a_rejected_token_are_private
      %i[update_expires_at refresh_rejected_token! retrying_rejected_token carried_token?].each do |name|
        refute_respond_to @authenticator, name
      end
    end

    def test_update_expires_at_sets_the_expiration_time
      expires_at = Time.now + 7200
      @authenticator.send(:update_expires_at, expires_at)

      assert_equal expires_at, @authenticator.expires_at
    end

    def test_update_expires_at_clears_the_expiration_time
      @authenticator.send(:update_expires_at, nil)

      assert_nil @authenticator.expires_at
      refute_predicate @authenticator, :token_expired?
    end

    def test_update_expires_at_waits_for_the_lock_a_refresh_holds
      mutex = @authenticator.instance_variable_get(:@mutex)
      updating = mutex.synchronize do
        Thread.new { @authenticator.send(:update_expires_at, nil) }.tap do |thread|
          Thread.pass until thread.status.eql?("sleep")

          assert_equal @expires_at, @authenticator.expires_at
        end
      end
      updating.join

      assert_nil @authenticator.expires_at
    end
  end
end
