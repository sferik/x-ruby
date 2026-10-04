# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream asks for a body that is not compressed, since Net::HTTP would hold back each line of a compressed one until
  # enough had arrived to fill a block, unless the headers of the request or of the client name an Accept-Encoding
  class ClientGetStreamAcceptEncodingTest < Minitest::Test
    cover_client

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"

    def read(client, **)
      client.get_stream("tweets/sample/stream", **) { |response| response.read_body { nil } }
    end

    def test_a_stream_asks_for_a_body_that_is_not_compressed
      stub_request(:get, STREAM_URL).with(headers: {"Accept-Encoding" => "identity"}).to_return(body: "")
      read(Client.new(bearer_token: TEST_BEARER_TOKEN))

      assert_requested :get, STREAM_URL, headers: {"Accept-Encoding" => "identity"}
    end

    def test_an_accept_encoding_of_the_client_or_the_request_is_sent_in_its_place
      stub_request(:get, STREAM_URL).to_return(body: "")
      read(Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"accept-encoding" => "gzip"}))
      read(Client.new(bearer_token: TEST_BEARER_TOKEN), headers: {"Accept-Encoding" => "br"})

      assert_requested :get, STREAM_URL, headers: {"Accept-Encoding" => "gzip"}
      assert_requested :get, STREAM_URL, headers: {"Accept-Encoding" => "br"}
    end

    def test_a_request_that_is_not_a_stream_asks_for_no_encoding_of_its_own
      stub_request(:get, "https://api.x.com/2/users/me").to_return(body: "{}", headers: {"Content-Type" => "application/json"})
      Client.new(bearer_token: TEST_BEARER_TOKEN).get("users/me")

      assert_not_requested :get, "https://api.x.com/2/users/me", headers: {"Accept-Encoding" => "identity"}
    end
  end
end
