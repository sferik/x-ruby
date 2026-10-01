# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class OAuth2AuthorizationConnectionTest < Minitest::Test
    cover OAuth2Authorization

    REDIRECT_URI = "https://example.com/callback"
    CALLBACK = "state=STATE&code=CODE"
    TOKENS = {token_type: "bearer", access_token: "ACCESS", refresh_token: "REFRESH", expires_in: 7200}.freeze

    def authorization(**options)
      OAuth2Authorization.new(client_id: TEST_CLIENT_ID, redirect_uri: REDIRECT_URI, state: "STATE", code_verifier: "a" * 43, **options)
    end

    def stub_token(status: 200, body: TOKENS)
      stub_request(:post, "https://api.x.com/2/oauth2/token").to_return(status:, body: body.to_json)
    end

    def test_the_code_is_exchanged_over_the_connection_settings_of_the_client
      stub_token
      output = StringIO.new
      authorization = authorization(proxy_url: "http://proxy.example.com:8080", read_timeout: 2, write_timeout: 7, keep_alive_timeout: 4)
      connection = exchanged_over do
        authorization.client(CALLBACK, proxy_url: "http://other.example.com:3128", open_timeout: 1, read_timeout: 5, debug_output: output)
      end

      assert_equal ["http://other.example.com:3128", 1, 5, 7, 4, output],
        [connection.send(:proxy_url), connection.open_timeout, connection.read_timeout, connection.write_timeout, connection.keep_alive_timeout, connection.debug_output]
    end

    def test_the_code_is_exchanged_over_the_connection_settings_of_the_authorization_the_client_is_not_given
      stub_token
      authorization = authorization(proxy_url: "http://proxy.example.com:8080", read_timeout: 2)
      connection = exchanged_over { authorization.client(CALLBACK, max_retries: 0) }

      assert_equal ["http://proxy.example.com:8080", 2], [connection.send(:proxy_url), connection.read_timeout]
    end

    def test_the_connection_of_the_exchange_of_a_client_is_closed_once_the_code_is_exchanged
      stub_token
      authorization = authorization()

      assert_predicate exchanged_over { authorization.client(CALLBACK) }, :closed?
    end

    def test_the_connection_of_the_exchange_of_a_client_is_closed_when_the_exchange_fails
      stub_token(status: 400, body: {error: "invalid_grant"})
      authorization = authorization()
      connection = exchanged_over { assert_raises(AuthorizationError) { authorization.client(CALLBACK) } }

      assert_predicate connection, :closed?
    end

    def test_the_credentials_are_exchanged_over_the_connection_of_the_authorization_which_is_closed_after
      stub_token
      authorization = authorization()
      connection = exchanged_over { authorization.tokens(CALLBACK) }

      assert_same authorization.send(:connection), connection
      assert_predicate connection, :closed?
    end

    def test_the_connection_of_the_authorization_is_closed_when_the_exchange_fails
      stub_token(status: 400, body: {error: "invalid_grant"})
      authorization = authorization()
      connection = exchanged_over { assert_raises(AuthorizationError) { authorization.tokens(CALLBACK) } }

      assert_predicate connection, :closed?
    end

    def test_the_tokens_leave_no_connection_open
      stub_token
      authorization = authorization()
      authorization.tokens(CALLBACK)

      assert_empty authorization.send(:connection).instance_variable_get(:@pool).instance_variable_get(:@idle).values.flatten
    end

    private

    # Record the connection each token request is sent over, which then answers closed?
    def record(connections, fetch)
      lambda do |request, connection:, refusal:|
        connections << connection
        connection.define_singleton_method(:close) { (@closed = true) && super() }
        connection.define_singleton_method(:closed?) { @closed.eql?(true) }
        fetch.call(request, connection:, refusal:)
      end
    end

    # The one connection the token requests of the block were sent over
    def exchanged_over
      token_endpoint = Core.const_get(:TokenEndpoint)
      connections = []
      token_endpoint.stub(:fetch, record(connections, token_endpoint.method(:fetch))) { yield }

      assert_equal 1, connections.size
      connections.first
    end
  end
end
