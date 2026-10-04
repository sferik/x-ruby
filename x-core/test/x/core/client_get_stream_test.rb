# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A GET request whose body the block reads as it arrives, which carries the credentials and headers of the client as
  # any other request does
  class ClientGetStreamTest < Minitest::Test
    cover_client
    cover Core.const_get(:Connection)

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"X-Client" => "client"})
    end

    def test_the_block_reads_the_body_as_it_arrives_and_its_value_is_returned
      stub_request(:get, "#{STREAM_URL}?expansions=author_id").to_return(body: "{\"data\":1}\r\n")
      chunks = []

      assert_equal :read, @client.get_stream("tweets/sample/stream", params: {expansions: "author_id"}) { |response|
        assert_instance_of StreamResponse, response
        response.read_body { |chunk| chunks << chunk }
        :read
      }
      assert_equal ["{\"data\":1}\r\n"], chunks
    end

    def test_the_request_carries_the_credentials_and_headers_of_the_client
      stub_request(:get, STREAM_URL)
      @client.get_stream("tweets/sample/stream", headers: {"X-Stream" => "stream"}) { |_response| }

      assert_requested(:get, STREAM_URL, headers: {"Authorization" => "Bearer #{TEST_BEARER_TOKEN}", "X-Client" => "client", "X-Stream" => "stream"})
    end

    def test_a_request_to_another_origin_carries_none_of_the_credentials
      stub_request(:get, "https://stream.example.com/sample")
      @client.get_stream("https://stream.example.com/sample") { |_response| }

      assert_requested(:get, "https://stream.example.com/sample") { |request| !request.headers.key?("Authorization") }
    end

    def test_a_block_is_required
      error = assert_raises(ArgumentError) { @client.get_stream("tweets/sample/stream") }

      assert_equal "get_stream takes a block, which reads the body of the response", error.message
    end

    def test_an_endpoint_that_is_not_a_url_raises_before_a_request
      assert_raises(ArgumentError) { @client.get_stream("http://[bad") { |_response| } }
    end

    def test_a_rejected_app_token_is_fetched_again_and_the_request_sent_again
      token_request = stub_request(:post, APP_ONLY_TOKEN_URL).to_return(status: 200, body: {token_type: "bearer", access_token: "FETCHED"}.to_json)
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer STALE"}).to_return(status: 401)
      stub_request(:get, STREAM_URL).with(headers: {"Authorization" => "Bearer FETCHED"}).to_return(body: "{}")
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, bearer_token: "STALE")

      assert_equal "{}", client.get_stream("tweets/sample/stream") { |response| response.read_body { |chunk| break chunk } }
      assert_requested token_request, times: 1
    end
  end
end
