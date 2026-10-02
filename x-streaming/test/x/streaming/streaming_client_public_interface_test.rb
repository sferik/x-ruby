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

    def test_a_streaming_client_built_with_no_settings_takes_the_defaults
      streaming = StreamingClient.new(Client.new)

      assert_equal [StreamingClient::DEFAULT_READ_TIMEOUT, StreamingClient::DEFAULT_MAX_RECONNECTS], [streaming.read_timeout, streaming.max_reconnects]
    end

    def test_the_settings_are_read_from_the_connection_and_the_reconnect_handler
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming(read_timeout: 25, max_reconnects: 6)

      assert_equal [25, 6], [streaming_client.read_timeout, streaming_client.max_reconnects]
    end

    def test_the_settings_of_the_client_are_read_from_the_client_alone
      %i[open_timeout write_timeout debug_output].each { |setting| refute_respond_to StreamingClient.new(Client.new), setting }
    end
  end
end
