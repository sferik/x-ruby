# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/chunks"

module X
  # Of the errors of the chunks that failed, one that holds the tokens of a refresh save_tokens raised for is raised
  # in place of any other, whichever chunk failed first, and the last of them, which holds the latest tokens
  class ChunksTokenReportTest < Minitest::Test
    cover Uploads.const_get(:Chunks)

    CHUNK_BYTES = 1024

    # A client whose requests each wait until as many have begun as it has failures, then fail with them in turn
    class FailingInTurnClient
      def initialize(failures)
        @failures = failures
        @count = failures.size
        @began = Thread::Queue.new
        @turn = Mutex.new
      end

      def post(*, **)
        @began << true
        Thread.pass until @began.size.eql?(@count)
        @turn.synchronize { raise @failures.shift }
      end
    end

    def test_a_failure_to_store_the_tokens_of_a_refresh_is_raised_in_place_of_a_chunk_that_failed_before_it
      report = TokenReportFailed.new

      assert_same report, assert_raises(TokenReportFailed) { append(BadRequest.new("refused"), report, BadRequest.new("refused")) }
    end

    def test_the_last_failure_to_store_the_tokens_of_a_refresh_is_raised_which_holds_the_latest_tokens
      latest = TokenReportFailed.new

      assert_same latest, assert_raises(TokenReportFailed) { append(TokenReportFailed.new, latest) }
    end

    def test_the_first_chunk_that_failed_is_raised_when_none_failed_to_store_tokens
      first = BadRequest.new("refused")

      assert_same first, assert_raises(BadRequest) { append(first, Forbidden.new("forbidden")) }
    end

    private

    # Upload as many chunks at once as there are failures, each of which fails with the next of them
    def append(*failures)
      source = Uploads.const_get(:Source).for(StringIO.new("\x01".b * (failures.size * CHUNK_BYTES)))
      Uploads.const_get(:Chunks).append(client: FailingInTurnClient.new(failures), source:, chunk_size: CHUNK_BYTES,
        media: {"id" => "1"}, boundary: "b", concurrency: failures.size)
    end
  end
end
