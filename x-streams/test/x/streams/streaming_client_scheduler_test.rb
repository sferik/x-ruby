# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A stream that a Fiber scheduler runs, which stop raises in no read of, is stopped at the next keep-alive
  class StreamingClientSchedulerTest < Minitest::Test
    cover StreamingClient

    POST = "{\"data\":{\"id\":\"1\"}}\r\n"

    def setup
      @streaming = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming
    end

    def test_a_stream_a_fiber_scheduler_runs_that_was_stopped_is_stopped_at_the_next_keep_alive
      delivered = []
      answer_stopping(["\r\n", POST])
      returned = Fiber.stub(:scheduler, Object.new) do
        Fiber.new(blocking: false) { @streaming.stream("tweets/sample/stream") { |post| delivered << post } }.resume
      end

      assert_equal [nil, []], [returned, delivered]
    end

    private

    # Answer the stream of the streaming client with a body that stops the streaming client, and then delivers the
    # chunks given
    def answer_stopping(chunks)
      streaming = @streaming
      streaming.instance_variable_get(:@stream_client).define_singleton_method(:get_stream) do |endpoint, **, &block|
        response = Net::HTTPOK.new("1.1", "200", "OK")
        response.uri = URI.join("https://api.x.com/2/", endpoint)
        response.define_singleton_method(:read_body) { |&read| streaming.stop || chunks.each { |chunk| read.call(chunk) } }
        block.call(stream_response(response))
      end
    end
  end
end
