# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class OAuth2AuthenticatorExpirationTest < Minitest::Test
    cover OAuth2Authenticator
    cover Core.const_get(:OAuth2Refresh)

    def test_the_refresh_of_a_rejected_token_is_private
      authenticator = OAuth2Authenticator.new(**test_oauth2_credentials, expires_at: Time.now + 60)

      %i[refresh_rejected_token! retrying_rejected_token].each do |name|
        refute_respond_to authenticator, name
      end
    end
  end
end
