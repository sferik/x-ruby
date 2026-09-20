# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientRetriesTest < Minitest::Test
    cover_client

    URL = "https://api.x.com/2/users/me"
    SUCCESS = {status: 200, body: '{"data":{"id":"1"}}', headers: {"Content-Type" => "application/json"}}.freeze

    def setup
      @sleeps = []
      @responses = []
    end

    def test_a_client_retries_nothing_by_default
      assert_equal 0, Client.new.max_retries
    end

    def test_the_option_is_copied_and_can_be_replaced
      client = Client.new(max_retries: 2)

      assert_equal [2, 1], [client.copy.max_retries, client.copy(max_retries: 1).max_retries]
    end

    def test_a_lookup_is_sent_again_after_the_api_fails_to_answer
      client = retrying_client
      stub_request(:get, URL).to_return({status: 503}, SUCCESS)

      assert_equal({"data" => {"id" => "1"}}, without_sleeping(client) { client.get("users/me") })
      assert_equal [[503, 200], [1]], [@responses, @sleeps]
    end

    def test_a_lookup_is_sent_again_after_a_network_error
      client = retrying_client
      stub_request(:get, URL).to_raise(EOFError).then.to_return(SUCCESS)

      assert_equal({"data" => {"id" => "1"}}, without_sleeping(client) { client.get("users/me") })
      assert_equal [1], @sleeps
    end

    def test_a_lookup_is_signed_afresh_each_time
      client = retrying_client(**test_oauth_credentials)
      nonces = []
      stub_request(:get, URL).with { |request| nonces << request.headers["Authorization"][/oauth_nonce="([^"]+)"/, 1] }.to_return({status: 500}, SUCCESS)
      without_sleeping(client) { client.get("users/me") }

      assert_equal 2, nonces.uniq.size
    end

    def test_a_post_is_not_sent_again
      client = retrying_client
      stub_request(:post, "https://api.x.com/2/tweets").to_return(status: 503)

      assert_raises(ServiceUnavailable) { without_sleeping(client) { client.post("tweets", {text: "hi"}) } }
      assert_requested(:post, "https://api.x.com/2/tweets", times: 1)
      assert_empty @sleeps
    end

    def test_a_refusal_the_request_is_the_reason_for_is_raised_at_once
      client = retrying_client
      stub_request(:get, URL).to_return(status: 404)

      assert_raises(NotFound) { without_sleeping(client) { client.get("users/me") } }
      assert_requested(:get, URL, times: 1)
    end

    def test_the_error_is_raised_once_the_retries_run_out
      client = retrying_client
      stub_request(:get, URL).to_return(status: 502)

      assert_raises(BadGateway) { without_sleeping(client) { client.get("users/me") } }
      assert_equal [[502, 502], [1]], [@responses, @sleeps]
    end

    private

    def retrying_client(**credentials)
      Client.new(**credentials, max_retries: 1, on_response: ->(response) { @responses << response.status })
    end

    def without_sleeping(client, &)
      client.instance_variable_get(:@retry_handler).stub(:sleep, ->(seconds) { @sleeps << seconds }, &)
    end
  end
end
