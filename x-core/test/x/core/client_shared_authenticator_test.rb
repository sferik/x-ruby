require_relative "../../test_helper"

module X
  class ClientSharedAuthenticatorTest < Minitest::Test
    cover Client

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN", expires_in: 7200}.to_json)
    end

    def stub_users_me(access_token)
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: {"Authorization" => "Bearer #{access_token}"})
        .to_return(status: 200, headers: {"Content-Type" => "application/json"}, body: '{"data":{"id":"1"}}')
    end

    def stub_token_refresh_without_a_lifetime
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
    end

    def test_a_refresh_that_reports_no_lifetime_clears_the_expiration_time_of_the_client
      stub_token_refresh_without_a_lifetime
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 1)
      client.authenticator.refresh_token!

      assert_nil client.expires_at
    end

    def test_a_copy_shares_the_authenticator_after_a_refresh_that_reports_no_lifetime
      refresh = stub_token_refresh_without_a_lifetime
      stub_users_me("NEW_ACCESS_TOKEN")
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 1)
      client.authenticator.refresh_token!
      copy = client.copy
      copy.get("users/me")

      assert_same client.authenticator, copy.authenticator
      assert_requested refresh, times: 1
    end

    def test_the_client_reads_an_empty_token_of_its_authenticator_rather_than_the_one_it_was_given
      client = Client.new(**test_oauth2_credentials)
      authenticator = client.authenticator
      authenticator.instance_variable_set(:@access_token, nil)
      authenticator.instance_variable_set(:@refresh_token, nil)

      assert_equal [nil, nil], [client.access_token, client.refresh_token]
    end

    def test_changing_another_credential_keeps_sharing_the_authenticator
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now + 3600)
      copy = client.copy
      client.api_key = "KEY"

      assert_same copy.authenticator, client.authenticator
      assert_equal [true, true], client.instance_variable_get(:@token_refresh_clients).then { |clients| [clients[client], clients[copy]] }
    end

    def test_changing_an_oauth2_credential_builds_an_authenticator_of_its_own
      %i[client_id client_secret access_token refresh_token].each do |credential|
        client = Client.new(**test_oauth2_credentials)
        copy = client.copy
        client.public_send(:"#{credential}=", "OTHER")

        refute_same copy.authenticator, client.authenticator
        assert_equal "OTHER", client.authenticator.public_send(credential)
      end
    end

    def test_a_copy_given_other_credentials_no_longer_hears_of_the_refreshes_of_the_client
      refreshed = []
      client = Client.new(**test_oauth2_credentials, on_token_refresh: ->(authenticator) { refreshed << [:client, authenticator.refresh_token] })
      copy = client.copy(on_token_refresh: ->(authenticator) { refreshed << [:copy, authenticator.refresh_token] })
      copy.update_credentials(access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN")
      client.authenticator.refresh_token!

      assert_equal [[:client, "NEW_REFRESH_TOKEN"]], refreshed
    end

    def test_a_copy_given_other_credentials_reports_its_own_refreshes
      refreshed = []
      client = Client.new(**test_oauth2_credentials, on_token_refresh: ->(_) { refreshed << :client })
      copy = client.copy(on_token_refresh: ->(_) { refreshed << :copy })
      copy.update_credentials(access_token: "OTHER_ACCESS_TOKEN", refresh_token: "OTHER_REFRESH_TOKEN")
      copy.authenticator.refresh_token!

      assert_equal [:copy], refreshed
    end

    def test_a_client_that_stops_authenticating_with_oauth2_no_longer_hears_of_refreshes
      refreshed = []
      client = Client.new(**test_oauth2_credentials)
      copy = client.copy(on_token_refresh: ->(_) { refreshed << :copy })
      copy.update_credentials(client_id: nil, client_secret: nil, access_token: nil, refresh_token: nil, bearer_token: TEST_BEARER_TOKEN)
      client.authenticator.refresh_token!

      assert_empty refreshed
    end
  end
end
