# frozen_string_literal: true

require "yaml"
require_relative "../../test_helper"

module X
  # A streaming client holds the client it streams for, and its credentials, so it refuses Marshal and YAML, which would
  # write them in the clear wherever it is kept, as the client does
  class StreamingClientMarshalTest < Minitest::Test
    cover StreamingClient

    def setup
      @streaming_client = Client.new(api_key: "KEY", api_key_secret: "SECRET", bearer_token: "BEARER").streaming
    end

    def test_a_streaming_client_refuses_marshal
      error = assert_raises(TypeError) { Marshal.dump(@streaming_client) }

      assert_equal "X::StreamingClient holds credentials, which Marshal would write in the clear wherever it is kept; keep the " \
        "credentials in a secret store, and the X::OAuth2Tokens save_tokens is passed, and build it again from them", error.message
    end

    def test_a_streaming_client_refuses_yaml
      error = assert_raises(TypeError) { YAML.dump(@streaming_client) }

      assert_equal "X::StreamingClient holds credentials, which YAML would write in the clear wherever it is kept; keep the " \
        "credentials in a secret store, and the X::OAuth2Tokens save_tokens is passed, and build it again from them", error.message
    end
  end
end
