# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientRefusedAuthenticatorTest < Minitest::Test
    cover_client

    def setup
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, headers: {"Content-Type" => "application/json"},
          body: {token_type: "bearer", access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN", expires_in: 7200}.to_json)
      @authenticator = OAuth2Authenticator.new(client_id: TEST_CLIENT_ID, access_token: TEST_ACCESS_TOKEN, refresh_token: TEST_REFRESH_TOKEN)
    end

    def refused_client(**options)
      reported = []
      assert_raises(ArgumentError) do
        Client.new(authenticator: @authenticator, on_token_refresh: ->(tokens) { reported << tokens }, proxy_url: "http://proxy.invalid:1", **options)
      end
      reported
    end

    def test_a_client_refused_for_a_setting_leaves_the_authenticator_it_was_given_alone
      reported = refused_client(max_retries: -1)
      client = Client.new(authenticator: @authenticator)
      @authenticator.refresh!

      assert_same internals(client).instance_variable_get(:@connection), @authenticator.send(:connection)
      assert_empty reported
    end

    def test_a_client_refused_for_its_base_url_leaves_the_authenticator_it_was_given_alone
      reported = refused_client(base_url: "api.x.com/2/")
      Client.new(authenticator: @authenticator)
      @authenticator.refresh!

      assert_empty reported
    end

    def test_a_copy_refused_for_a_setting_leaves_the_authenticator_it_shares_alone
      client = Client.new(authenticator: @authenticator)
      reported = []
      assert_raises(ArgumentError) { client.with(on_token_refresh: ->(tokens) { reported << tokens }, max_redirects: -1) }
      @authenticator.refresh!

      assert_empty reported
    end
  end
end
