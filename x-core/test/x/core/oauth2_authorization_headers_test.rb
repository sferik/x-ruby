# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The code of an authorization is exchanged with the User-Agent of the gem and the headers of the authorization, or
  # of the client it is exchanged for
  class OAuth2AuthorizationHeadersTest < Minitest::Test
    cover OAuth2Authorization
    cover Core.const_get(:TokenEndpoint)

    USER_AGENT = Core.const_get(:RequestBuilder)::DEFAULT_HEADERS.fetch("User-Agent")
    GATEWAY = {"X-Gateway-Key" => "g"}.freeze
    REDIRECT_URI = "https://example.com/callback"
    CALLBACK = "state=STATE&code=CODE"

    def authorization(**options)
      OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: REDIRECT_URI, state: "STATE", code_verifier: "a" * 43, **options)
    end

    def stub_refresh(**options)
      stub_request(:post, OAUTH2_TOKEN_URL).with(**options).to_return(headers: {"Content-Type" => "application/json"},
        body: {token_type: "bearer", access_token: "new", refresh_token: "next", expires_in: 7200}.to_json)
    end

    def test_the_code_is_exchanged_with_the_headers_of_the_authorization
      exchange = stub_refresh(headers: {**GATEWAY, "User-Agent" => USER_AGENT})
      authorization(headers: {x_gateway_key: "g"}).tokens(CALLBACK)

      assert_requested exchange
    end

    def test_the_code_is_exchanged_for_a_client_with_the_headers_of_the_authorization_it_is_not_given_others
      exchange = stub_refresh(headers: GATEWAY)

      assert_equal GATEWAY, authorization(headers: GATEWAY).client(CALLBACK).headers
      assert_requested exchange
    end

    def test_the_code_is_exchanged_for_a_client_with_the_headers_it_is_given
      exchange = stub_refresh(headers: {"X-Other" => "o"})
      authorization(headers: GATEWAY).client(CALLBACK, headers: {"X-Other" => "o"})

      assert_requested exchange
      assert_not_requested :post, OAUTH2_TOKEN_URL, headers: GATEWAY
    end

    def test_an_authorization_refuses_headers_that_are_not_a_hash
      error = assert_raises(ArgumentError) { authorization(headers: "X-Gateway-Key: g") }

      assert_equal "headers must be a Hash of header names to values, not a String", error.message
    end

    def test_an_authorization_sends_no_headers_of_its_own_by_default
      exchange = stub_refresh(headers: {"User-Agent" => USER_AGENT})
      client = authorization.client(CALLBACK)

      assert_requested exchange
      assert_empty client.headers
    end
  end
end
