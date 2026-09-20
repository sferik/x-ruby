require_relative "../../test_helper"

module X
  class ClientCloseTest < Minitest::Test
    cover Client

    def setup
      stub_request(:post, AppOnlyAuthenticator::TOKEN_URL)
        .to_return(status: 200, body: {token_type: "bearer", access_token: TEST_BEARER_TOKEN}.to_json)
      stub_request(:get, "https://api.x.com/2/tweets")
    end

    def opened_by(client, &)
      clients = []
      connection = client.instance_variable_get(:@connection)
      original = connection.method(:build_http_client)
      connection.stub(:build_http_client, ->(*args) { original.call(*args).tap { |http_client| clients << http_client } }, &)
      clients
    end

    def test_close_closes_the_connections_kept_open
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      http_clients = opened_by(client) do
        client.get("tweets")
        client.close
      end

      assert_equal [false], http_clients.map(&:started?)
    end

    def test_a_request_after_close_opens_a_connection_again
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      http_clients = opened_by(client) do
        client.get("tweets")
        client.close
        client.get("tweets")
      end

      assert_equal [false, true], http_clients.map(&:started?)
    end

    def test_close_closes_the_connections_of_the_app_only_copy
      client = Client.new(**test_oauth_credentials)
      http_clients = opened_by(client.app_only) do
        client.app_only.get("tweets")
        client.close
      end

      assert_equal [false], http_clients.map(&:started?)
    end

    def test_a_change_of_settings_closes_the_connections_of_the_app_only_copy_it_replaces
      client = Client.new(**test_oauth_credentials)
      copy = client.app_only
      http_clients = opened_by(copy) do
        copy.get("tweets")
        client.read_timeout = 5
        client.app_only
      end

      assert_equal [false], http_clients.map(&:started?)
    end

    def test_close_makes_no_app_only_copy
      client = Client.new(**test_oauth_credentials)
      client.close

      assert_empty client.instance_variable_get(:@app_only)
    end
  end
end
