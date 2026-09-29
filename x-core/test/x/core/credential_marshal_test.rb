# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # What holds credentials refuses Marshal, which would write them in the clear wherever it is kept
  class CredentialMarshalTest < Minitest::Test
    cover Core::CredentialHolder

    def holders
      client = Client.new(api_key: "KEY", api_key_secret: "SECRET", bearer_token: "BEARER")
      [client, client.streaming, BearerTokenAuthenticator.new(bearer_token: "BEARER"),
        OAuth1Authenticator.new(api_key: "KEY", api_key_secret: "SECRET", access_token: "1-TOKEN", access_token_secret: "TOKEN_SECRET"),
        OAuth2Authenticator.new(client_id: "CLIENT", access_token: "ACCESS", refresh_token: "REFRESH"),
        AppOnlyAuthenticator.new(api_key: "KEY", api_key_secret: "SECRET"), Class.new(Authenticator).new,
        OAuth2Authorization.new(client_id: "CLIENT", client_secret: "CLIENT_SECRET", redirect_uri: "https://example.com/callback")]
    end

    def test_what_holds_credentials_refuses_marshal
      holders.each do |holder|
        error = assert_raises(TypeError) { Marshal.dump(holder) }

        assert_equal "#{holder.class} holds credentials, which Marshal would write in the clear wherever it is kept; keep the credentials " \
          "in a secret store, and the X::OAuth2Tokens on_token_refresh is passed, and build it again from them", error.message
      end
    end

    def test_what_holds_credentials_refuses_marshal_within_what_is_marshalled
      assert_raises(TypeError) { Marshal.dump({"client" => Client.new(bearer_token: "BEARER")}) }
    end

    def test_the_tokens_of_a_refresh_still_marshal
      tokens = OAuth2Tokens.new(access_token: "ACCESS", refresh_token: "REFRESH")

      assert_equal tokens, Marshal.load(Marshal.dump(tokens))
    end

    def test_the_message_is_named_privately
      assert_raises(NameError) { Core::CredentialHolder::MARSHAL_MESSAGE }
    end
  end
end
