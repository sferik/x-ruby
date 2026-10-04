# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An authenticator built by hand keeps frozen copies of the credentials it was given, so a caller that changes its
  # own Strings afterwards changes nothing the authenticator sends
  class AuthenticatorCredentialsFrozenTest < Minitest::Test
    cover OAuth1Authenticator
    cover BearerTokenAuthenticator
    cover AppOnlyAuthenticator
    cover OAuth2Authenticator
    cover Core.const_get(:ClientCredentials)

    def test_each_authenticator_holds_frozen_copies_of_its_credentials
      authenticators.each do |authenticator, names|
        names.each do |name|
          value = authenticator.instance_variable_get(:"@#{name}")

          assert_equal [name.to_s.upcase, true], [value, value.frozen?], "#{authenticator.class} #{name}"
        end
      end
    end

    private

    def authenticators
      [[OAuth1Authenticator.new(**strings(:api_key, :api_key_secret, :access_token, :access_token_secret)), %i[api_key api_key_secret access_token access_token_secret]],
        [BearerTokenAuthenticator.new(**strings(:bearer_token)), %i[bearer_token]],
        [AppOnlyAuthenticator.new(**strings(:api_key, :api_key_secret, :bearer_token)), %i[api_key api_key_secret bearer_token]],
        [OAuth2Authenticator.new(**strings(:client_id, :client_secret, :access_token, :refresh_token)), %i[client_id client_secret access_token refresh_token]],
        [Core.const_get(:ClientInternals).allocate.tap { |internals| internals.__send__(:initialize_credentials, **strings(*CREDENTIALS), expires_at: nil, scopes: nil) }, CREDENTIALS]]
    end

    CREDENTIALS = %i[api_key api_key_secret access_token access_token_secret bearer_token client_id client_secret refresh_token].freeze

    def strings(*names) = names.to_h { |name| [name, +name.to_s.upcase] }
  end
end
