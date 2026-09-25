# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientWithRefreshTest < Minitest::Test
    cover_client

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN", expires_in: 7200}.to_json)
    end

    # A client whose credentials read the tokens it held before a refresh, as a copy built while another thread
    # refreshes reads them
    def client_read_before_a_refresh(**options)
      Client.new(**test_oauth2_credentials, **options).tap do |client|
        stale = client.send(:credentials)
        client.authenticator.refresh!
        client.define_singleton_method(:credentials) { stale }
      end
    end

    def test_a_copy_built_while_the_tokens_are_refreshed_shares_the_authenticator
      client = client_read_before_a_refresh
      copy = client.with

      assert_same client.authenticator, copy.authenticator
      assert_equal "NEW_REFRESH_TOKEN", copy.send(:refresh_token)
    end

    def test_a_copy_built_while_the_tokens_are_refreshed_keeps_the_expiration_time_of_the_refresh
      client = client_read_before_a_refresh(expires_at: Time.now + 60)
      expires_at = client.expires_at
      client.with

      assert_equal expires_at, client.expires_at
    end

    def test_a_copy_refreshes_an_expired_token_over_its_own_connection
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 60)
      copy = client.with(proxy_url: "http://proxy.example.com:8080", read_timeout: 5)
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 200, body: "{}")

      assert_same copy_connection(copy), connections_of_refreshes { copy.get("users/me") }.first
      assert_same client.authenticator, copy.authenticator
    end

    def test_a_copy_refreshes_a_rejected_token_over_its_own_connection
      copy = Client.new(**test_oauth2_credentials).with(debug_output: StringIO.new)
      stub_request(:get, "https://api.x.com/2/users/me").to_return({status: 401}, {status: 200, body: "{}"})

      assert_same copy_connection(copy), connections_of_refreshes { copy.get("users/me") }.first
    end

    def test_requests_an_endpoint_always_rejects_spend_one_refresh_between_them
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 401)
      client = Client.new(**test_oauth2_credentials)

      3.times { assert_raises(Unauthorized) { client.with.get("users/me") } }
      assert_requested :post, "https://api.x.com/2/oauth2/token", times: 1
    end

    def test_a_copy_given_the_credentials_the_authenticator_holds_shares_it
      client = Client.new(**test_oauth2_credentials)
      copy = client.with(client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN)

      assert_same client.authenticator, copy.authenticator
    end

    def test_a_copy_given_another_token_builds_an_authenticator_of_its_own
      client = Client.new(**test_oauth2_credentials)
      copy = client.with(access_token: "OTHER_ACCESS_TOKEN")

      refute_same client.authenticator, copy.authenticator
      assert_equal ["OTHER_ACCESS_TOKEN", TEST_ACCESS_TOKEN], [copy.authenticator.access_token, client.authenticator.access_token]
    end

    def test_a_copy_given_another_client_secret_builds_an_authenticator_of_its_own
      client = Client.new(**test_oauth2_credentials)
      copy = client.with(client_secret: "OTHER_SECRET")

      refute_same client.authenticator, copy.authenticator
    end

    def test_a_copy_given_other_tokens_keeps_the_expiration_time_of_the_client
      expires_at = Time.now + 60
      copy = Client.new(**test_oauth2_credentials, expires_at:).with(access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN")

      assert_equal expires_at, copy.expires_at
    end

    def test_a_copy_that_signs_with_oauth1_keeps_its_own_authenticator
      client = Client.new(**test_oauth2_credentials)
      copy = client.with(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, access_token_secret: TEST_ACCESS_TOKEN_SECRET)

      assert_instance_of OAuth1Authenticator, copy.authenticator
    end

    private

    def copy_connection(copy) = copy.instance_variable_get(:@connection)

    # The connections the token requests a block sends are sent over
    def connections_of_refreshes
      connections = []
      fetch = Core::TokenEndpoint.method(:fetch)
      Core::TokenEndpoint.stub(:fetch, ->(request, connection:) { fetch.call(request, connection: connections.push(connection).last) }) { yield }
      connections
    end
  end
end
