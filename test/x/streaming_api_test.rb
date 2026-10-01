# frozen_string_literal: true

require_relative "../test_helper"

module X
  class ClientStreamingAPITest < Minitest::Test
    def test_client_includes_streaming_api
      assert_includes Client.ancestors, Streaming::API
    end

    def test_a_client_builds_a_streaming_client_of_itself
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      streaming = client.streaming(read_timeout: 25, max_reconnects: 2)

      assert_equal [StreamingClient, client, 25, 2], [streaming.class, streaming.client, streaming.read_timeout, streaming.max_reconnects]
    end
  end
end
