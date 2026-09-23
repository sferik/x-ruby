# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/chunks"

module X
  # A chunk is sent again as often as its client sends a request again
  class ChunksRetriesTest < Minitest::Test
    cover Uploader.const_get(:Chunks)

    def chunks = Uploader.const_get(:Chunks)

    def test_a_chunk_is_sent_again_as_often_as_the_client_says
      assert_equal 5, chunks.send(:max_retries_of, Client.new(max_retries: 5))
    end

    def test_a_chunk_of_a_client_that_says_nothing_is_sent_again_as_often_as_a_client_does_by_default
      assert_equal Client::DEFAULT_MAX_RETRIES, chunks.send(:max_retries_of, Object.new)
    end
  end
end
