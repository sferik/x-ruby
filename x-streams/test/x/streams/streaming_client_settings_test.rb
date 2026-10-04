# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A streaming client takes its read timeout and reconnects, and checks them, and the classes and endpoint of a stream,
  # before it opens one
  class StreamingClientSettingsTest < Minitest::Test
    cover StreamingClient
    cover Streams.const_get(:Validator)
    cover Streams.const_get(:ReconnectHandler)

    NOT_A_URL = "it is not a valid URL; escape what a URL may not hold, such as a space"
    NOT_HTTP = "it does not name an http or https URL"
    ARRAY_CLASS_MESSAGE = "%s must be a Class that JSON.parse builds each array into, such as Array, not %s"
    OBJECT_CLASS_MESSAGE = "%s must be a Class that JSON.parse builds each object into, such as Hash, or respond to " \
      "from_response, as the resource classes of x-resources do, not %s"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def message_of(&) = assert_raises(ArgumentError, &).message

    def test_a_streaming_client_takes_a_read_timeout_and_reconnects
      streaming = Client.new.streaming(read_timeout: 25, max_reconnects: 2)

      assert_equal [25, 2], [streaming.read_timeout, streaming.max_reconnects]
    end

    def test_a_streaming_client_defaults_its_read_timeout_and_reconnects
      streaming = Client.new.streaming

      assert_equal [StreamingClient::DEFAULT_READ_TIMEOUT, StreamingClient::DEFAULT_MAX_RECONNECTS], [streaming.read_timeout, streaming.max_reconnects]
    end

    def test_reconnects_that_are_neither_a_count_nor_infinity_are_refused_when_the_stream_is_built
      messages = ["5", nil, 1.5, -1, -Float::INFINITY].map { |value| message_of { Client.new.streaming(max_reconnects: value) } }

      assert_equal ['"5"', "nil", "1.5", "-1", "-Infinity"].map { |value| "max_reconnects must be an Integer of at least 0, or Float::INFINITY for no limit, not #{value}" }, messages
    end

    def test_reconnects_of_zero_or_infinity_are_allowed
      assert_equal [0, Float::INFINITY], [0, Float::INFINITY].map { |value| Client.new.streaming(max_reconnects: value).max_reconnects }
    end

    def test_a_streaming_client_checks_its_read_timeout
      messages = ["30", 0, 0.0, -1, 20, 24, 24.999, Rational(49, 2), Float::INFINITY, Float::NAN, Complex(30, 0)].map { |value| message_of { Client.new.streaming(read_timeout: value) } }

      assert_equal ['"30"', "0", "0.0", "-1", "20", "24", "24.999", "(49/2)", "Infinity", "NaN", "(30+0i)"].map { |value| "read_timeout must be a finite number of seconds of at least 25, five more than the 20-second interval of the keep-alive X sends a quiet stream, or nil for no timeout, not #{value}" }, messages
      assert_nil Client.new.streaming(read_timeout: nil).read_timeout
    end

    def test_a_read_timeout_of_at_least_25_is_allowed
      assert_equal [25, 25.0, 25.5, Rational(51, 2), 600], [25, 25.0, 25.5, Rational(51, 2), 600].map { |value| Client.new.streaming(read_timeout: value).read_timeout }
    end

    def test_the_classes_of_a_stream_are_checked_before_it_is_opened
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming

      assert_equal format(ARRAY_CLASS_MESSAGE, :array_class, '"Array"'), message_of { streaming_client.stream("tweets/search/stream", array_class: "Array") { nil } }
      assert_equal format(OBJECT_CLASS_MESSAGE, :object_class, '"Hash"'),
        message_of { streaming_client.stream("tweets/search/stream", object_class: "Hash") { nil } }
      assert_not_requested :any, /api\.x\.com/
    end

    def test_a_stream_of_an_invalid_endpoint_raises_before_it_connects
      streaming = @client.streaming
      invalid = {"tweets/search/stream?query=a%zz" => NOT_A_URL, "tweets/search stream" => NOT_A_URL, "foo:bar" => NOT_HTTP}
      invalid.each do |endpoint, reason|
        error = assert_raises(ArgumentError) { streaming.stream(endpoint) { flunk "unexpected yield" } }

        assert_equal "Invalid endpoint #{endpoint.inspect}: #{reason}", error.message
      end
      assert_not_requested :any, /api\.x\.com/
    end

    def test_the_validator_returns_what_it_checked
      assert_equal [Float::INFINITY, 3], [Float::INFINITY, 3].map { |value| Streams.const_get(:Validator).count_or_infinity!(:max_reconnects, value) }
    end

    def test_a_stream_takes_an_object_class_that_is_no_class_but_builds_objects
      builder = Module.new { def self.from_response(body, **) = body.dig("data", "id") }
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")

      assert_equal "1", @client.streaming(max_reconnects: 0).stream("tweets/search/stream", object_class: builder) { |id| break id }
    end
  end
end
