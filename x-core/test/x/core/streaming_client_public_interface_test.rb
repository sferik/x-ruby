# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A streaming client answers its settings, and nothing it reads them with
  class StreamingClientPublicInterfaceTest < Minitest::Test
    cover StreamingClient

    def test_the_class_offers_no_way_to_define_delegators
      %i[def_delegator def_delegators delegate def_instance_delegator def_instance_delegators instance_delegate].each do |name|
        refute_respond_to StreamingClient, name
      end
    end

    def test_the_settings_are_read_from_the_connection_and_the_reconnect_handler
      debug_output = StringIO.new
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, open_timeout: 3, write_timeout: 4, debug_output:)
      streaming_client = client.streaming(read_timeout: 5, max_reconnects: 6)

      assert_equal [3, 5, 4, 6], [streaming_client.open_timeout, streaming_client.read_timeout, streaming_client.write_timeout, streaming_client.max_reconnects]
      assert_same debug_output, streaming_client.debug_output
    end
  end
end
