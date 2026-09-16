require "base64"
require "digest"
require_relative "../../test_helper"

module X
  class OAuth2AuthorizationURLTest < Minitest::Test
    cover OAuth2Authorization

    REDIRECT_URI = "https://example.com/callback".freeze
    CODE_VERIFIER = ("a" * 43).freeze

    def authorization(**options)
      OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: REDIRECT_URI, **options)
    end

    def query_of(url) = URI.decode_www_form(URI(url).query).to_h

    def test_url_asks_x_to_authorize_the_app
      url = authorization(state: "STATE", code_verifier: CODE_VERIFIER).url
      challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(CODE_VERIFIER), padding: false)

      assert url.start_with?("https://x.com/i/oauth2/authorize?")
      assert_equal({"response_type" => "code", "client_id" => TEST_CLIENT_ID, "redirect_uri" => REDIRECT_URI,
                    "scope" => "tweet.read users.read offline.access", "state" => "STATE", "code_challenge" => challenge,
                    "code_challenge_method" => "S256"}, query_of(url))
    end

    def test_url_asks_for_the_scopes_given
      assert_equal "tweet.read tweet.write", query_of(authorization(scopes: %w[tweet.read tweet.write]).url)["scope"]
    end

    def test_a_new_authorization_generates_its_state_and_code_verifier
      first = authorization
      second = authorization

      refute_equal first.state, second.state
      refute_equal first.code_verifier, second.code_verifier
    end

    def test_a_generated_state_and_code_verifier
      authorization = authorization()

      assert_equal 43, authorization.state.size
      assert_match(/\A[A-Za-z0-9\-_]{64}\z/, authorization.code_verifier)
      assert_equal authorization.state, query_of(authorization.url)["state"]
    end

    def test_attributes
      connection = Connection.new
      authorization = authorization(client_secret: TEST_CLIENT_SECRET, scopes: %w[users.read], state: "STATE",
        code_verifier: CODE_VERIFIER, connection:)

      assert_equal [TEST_CLIENT_ID, TEST_CLIENT_SECRET, REDIRECT_URI, %w[users.read], "STATE", CODE_VERIFIER],
        [authorization.client_id, authorization.client_secret, authorization.redirect_uri, authorization.scopes, authorization.state, authorization.code_verifier]
      assert_same connection, authorization.connection
    end

    def test_defaults
      authorization = authorization()

      assert_nil authorization.client_secret
      assert_equal OAuth2Authorization::DEFAULT_SCOPES, authorization.scopes
      assert_instance_of Connection, authorization.connection
    end

    def test_a_nil_state_is_refused
      error = assert_raises(ArgumentError) { authorization(state: nil) }

      assert_equal "state must not be nil or empty; pass the state stored when the user was sent to X", error.message
    end

    def test_an_empty_state_is_refused
      assert_raises(ArgumentError) { authorization(state: "") }
    end

    def test_an_invalid_code_verifier_is_refused
      assert_raises(ArgumentError) { authorization(code_verifier: "short") }
    end

    def test_inspect_hides_the_secrets
      inspected = authorization(client_secret: TEST_CLIENT_SECRET, state: "STATE", code_verifier: CODE_VERIFIER).inspect

      assert_equal "#<X::OAuth2Authorization client_id=\"#{TEST_CLIENT_ID}\" redirect_uri=\"#{REDIRECT_URI}\" " \
        "scopes=[\"tweet.read\", \"users.read\", \"offline.access\"]>", inspected
    end
  end

  class OAuth2AuthorizationCodeTest < Minitest::Test
    cover OAuth2Authorization

    REDIRECT_URI = "https://example.com/callback".freeze
    CODE_VERIFIER = ("a" * 43).freeze
    TOKEN_BODY = "grant_type=authorization_code&code=CODE&redirect_uri=#{URI.encode_www_form_component(REDIRECT_URI)}&code_verifier=#{CODE_VERIFIER}".freeze
    TOKENS = {token_type: "bearer", access_token: "ACCESS", refresh_token: "REFRESH", expires_in: 7200}.freeze

    def authorization(**options)
      OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: REDIRECT_URI, state: "STATE", code_verifier: CODE_VERIFIER, **options)
    end

    def stub_token(body: TOKENS, status: 200)
      stub_request(:post, "https://api.x.com/2/oauth2/token").to_return(status:, body: body.to_json)
    end

    def test_credentials_of_a_public_client
      token = stub_token.with(body: "#{TOKEN_BODY}&client_id=#{TEST_CLIENT_ID}") { |request| !request.headers.key?("Authorization") }
      credentials = Time.stub(:now, Time.at(1_000)) { authorization.credentials("#{REDIRECT_URI}?state=STATE&code=CODE") }

      assert_equal({client_id: TEST_CLIENT_ID, client_secret: nil, access_token: "ACCESS", refresh_token: "REFRESH",
                    expires_at: Time.at(8_200)}, credentials)
      assert_requested token
    end

    def test_credentials_of_a_confidential_client
      basic = "Basic #{Base64.strict_encode64("#{TEST_CLIENT_ID}:#{TEST_CLIENT_SECRET}")}"
      token = stub_token.with(body: TOKEN_BODY, headers: {"Authorization" => basic})

      assert_equal TEST_CLIENT_SECRET, authorization(client_secret: TEST_CLIENT_SECRET).credentials("state=STATE&code=CODE")[:client_secret]
      assert_requested token
    end

    def test_credentials_from_query_parameters
      stub_token

      assert_equal "ACCESS", authorization.credentials({state: "STATE", code: "CODE"})[:access_token]
    end

    def test_credentials_without_a_refresh_token_are_a_bearer_token
      stub_token(body: {token_type: "bearer", access_token: "ACCESS", expires_in: 7200})

      assert_equal({bearer_token: "ACCESS"}, authorization.credentials("state=STATE&code=CODE"))
    end

    def test_credentials_are_exchanged_over_the_connection
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@body, TOKENS.to_json)
      response.instance_variable_set(:@read, true)
      connection = Connection.new
      requests = []
      connection.stub(:perform, ->(request:) { requests << request.body and response }) do
        authorization(connection:).credentials("state=STATE&code=CODE")
      end

      assert_equal ["#{TOKEN_BODY}&client_id=#{TEST_CLIENT_ID}"], requests
    end

    def test_client_acts_for_the_user
      stub_token
      client = authorization.client("state=STATE&code=CODE", base_url: "https://api.x.com/3/")

      assert_instance_of OAuth2Authenticator, client.authenticator
      assert_equal ["ACCESS", "REFRESH", "https://api.x.com/3/"], [client.access_token, client.refresh_token, client.base_url]
    end

    def test_a_denied_authorization_raises
      error = assert_raises(AuthorizationError) do
        authorization.credentials("error=access_denied&error_description=The+user+denied+the+request&state=STATE")
      end

      assert_equal ["The user denied the request", "access_denied"], [error.message, error.code]
      assert_not_requested :post, "https://api.x.com/2/oauth2/token"
    end

    def test_an_error_without_a_description_raises_its_code
      assert_equal "access_denied", assert_raises(AuthorizationError) { authorization.credentials("error=access_denied") }.message
    end

    def test_a_redirect_for_another_authorization_raises
      error = assert_raises(AuthorizationError) { authorization.credentials("state=OTHER&code=CODE") }

      assert_equal ["The authorization response answers a different request", nil], [error.message, error.code]
      assert_not_requested :post, "https://api.x.com/2/oauth2/token"
    end

    def test_a_refused_code_raises
      stub_token(status: 400, body: {error: "invalid_grant", error_description: "Value passed for the authorization code was invalid."})
      error = assert_raises(AuthorizationError) { authorization.credentials("state=STATE&code=CODE") }

      assert_equal ["Value passed for the authorization code was invalid.", "invalid_grant"], [error.message, error.code]
    end

    def test_a_redirect_that_is_not_a_valid_url_raises
      error = assert_raises(AuthorizationError) { authorization.credentials("https://exa mple.com/callback?state=STATE&code=CODE") }

      assert_equal ["The redirect back from X is not a valid URL", nil], [error.message, error.code]
      assert_not_requested :post, "https://api.x.com/2/oauth2/token"
    end

    def test_a_failure_without_a_reason_raises_the_default_message
      stub_request(:post, "https://api.x.com/2/oauth2/token").to_return(status: 500, body: "")
      error = assert_raises(AuthorizationError) { authorization.credentials("state=STATE&code=CODE") }

      assert_equal ["Authorization failed", nil], [error.message, error.code]
      assert_kind_of Error, error
    end
  end
end
