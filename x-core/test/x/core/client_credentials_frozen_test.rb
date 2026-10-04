# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client, its authenticators, and an authorization keep frozen copies of the credentials, tokens, headers, and
  # URLs they were given, so neither their callers nor what their readers return can change what they send, or where
  class ClientCredentialsFrozenTest < Minitest::Test
    cover_client
    cover OAuth1Authenticator
    cover BearerTokenAuthenticator
    cover AppOnlyAuthenticator
    cover OAuth2Authenticator
    cover OAuth2Authorization
    cover Core.const_get(:CredentialValidator)
    cover Core.const_get(:SettingValidator)
    cover OAuth2Tokens
    cover Core.const_get(:OAuth2Refresh)

    def test_a_bearer_token_changed_by_its_caller_changes_no_request
      token = +"TOKEN"
      client = Client.new(bearer_token: token)
      token.replace("")
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 200, body: "{}")
      client.get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"Authorization" => "Bearer TOKEN"}
    end

    def test_the_credentials_a_client_reads_are_frozen
      client = Client.new(**test_oauth_credentials)

      assert_predicate client.api_key, :frozen?
      assert_predicate client.authenticator.api_key, :frozen?
      assert_predicate Client.new(**test_oauth2_credentials).client_id, :frozen?
    end

    def test_the_header_values_a_client_reads_are_frozen_copies
      agent = +"my-app/1.0"
      client = Client.new(headers: {"User-Agent" => agent})
      agent.replace("changed")

      assert_equal "my-app/1.0", client.headers.fetch("User-Agent")
      assert_predicate client.headers.fetch("User-Agent"), :frozen?
    end

    def test_the_tokens_save_tokens_is_passed_share_no_string_a_hook_can_change
      saved = []
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 5, save_tokens: ->(tokens) { saved << tokens })
      stub_refresh
      client.get("users/me")

      assert_equal [true] * 4, [*saved.first.to_h.values_at(:access_token, :refresh_token), *held_tokens(client)].map(&:frozen?)
    end

    def test_tokens_hold_frozen_copies_of_the_strings_they_were_given
      access, refresh = +"ACCESS", +"REFRESH"
      tokens = OAuth2Tokens.new(access_token: access, refresh_token: refresh)
      access.replace("CHANGED")
      refresh.replace("CHANGED")

      assert_equal %w[ACCESS REFRESH], [tokens.access_token, tokens.refresh_token]
      assert_predicate tokens.access_token, :frozen?
      assert_predicate tokens.refresh_token, :frozen?
    end

    def test_an_authorization_exchanges_its_code_at_the_base_url_it_was_given
      base_url = +"https://api.x.com/2/"
      authorization = OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/cb", base_url:, state: "STATE")
      base_url.replace("https://evil.example/2/")
      stub_request(:post, "https://api.x.com/2/oauth2/token").to_return(status: 200, headers: {"Content-Type" => "application/json"},
        body: {token_type: "bearer", access_token: "AT"}.to_json)
      authorization.tokens("https://example.com/cb?state=STATE&code=CODE")

      assert_requested :post, "https://api.x.com/2/oauth2/token"
    end

    def test_an_authorization_holds_frozen_copies_of_its_credentials
      authorization = OAuth2Authorization.new(client_id: +"ID", client_secret: +"SECRET", redirect_uri: +"https://example.com/cb")

      assert_equal [true] * 3, %i[@client_id @client_secret @redirect_uri].map { |name| authorization.instance_variable_get(name).frozen? }
    end

    def test_an_authorization_holds_a_copy_of_a_proxy_url_given_as_a_uri
      uri = URI("http://proxy.example.com:8080")
      authorization = OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/cb", proxy_url: uri)
      uri.port = 9090

      assert_equal "http://proxy.example.com:8080", authorization.instance_variable_get(:@settings).fetch(:proxy_url)
      string = +"http://proxy.example.com:8080"
      authorization = OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: "https://example.com/cb", proxy_url: string)
      string.replace("http://elsewhere.example:1")

      assert_equal "http://proxy.example.com:8080", authorization.instance_variable_get(:@settings).fetch(:proxy_url)
    end

    private

    def held_tokens(client) = %i[@access_token @refresh_token].map { |name| client.authenticator.instance_variable_get(name) }

    def stub_refresh
      stub_request(:post, "https://api.x.com/2/oauth2/token").to_return(status: 200, headers: {"Content-Type" => "application/json"},
        body: {token_type: "bearer", access_token: "NEW", refresh_token: "NEW_REFRESH", expires_in: 7200}.to_json)
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 200, body: "{}")
    end
  end
end
