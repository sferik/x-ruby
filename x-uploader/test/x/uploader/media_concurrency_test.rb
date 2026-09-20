require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaConcurrencyTest < Minitest::Test
    cover Uploader::Media
    cover Uploader.const_get(:Chunks)

    BASE_URL = "https://api.x.com/2/media/upload".freeze
    APPEND_URL = "#{BASE_URL}/#{TEST_MEDIA_ID}/append".freeze
    CHUNK_BYTES = 1024
    JSON = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}.freeze

    def setup
      @client = Client.new
      @lock = Mutex.new
      @active = 0
      @most_active = 0
      stub_request(:post, "#{BASE_URL}/initialize").to_return(JSON)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(JSON)
    end

    def test_uploads_no_more_chunks_at_once_than_the_concurrency
      stub_slow_appends
      upload(chunks: 8, concurrency: 3)

      assert_equal 3, @most_active
      assert_requested(:post, APPEND_URL, times: 8)
    end

    def test_uploads_four_chunks_at_once_by_default
      stub_slow_appends
      upload(chunks: 8)

      assert_equal 4, @most_active
    end

    def test_starts_no_more_workers_than_chunks
      threads = []
      stub_slow_appends
      Thread.stub(:new, ->(&block) { Thread.start(&block).tap { |thread| threads << thread } }) { upload(chunks: 2, concurrency: 5) }

      assert_equal 2, threads.size
    end

    def test_a_failed_chunk_stops_the_chunks_not_yet_begun
      stub_failing_first_append(failure_wait: 0.02, success_wait: 0.1)

      assert_raises(BadRequest) { upload(chunks: 6, concurrency: 2) }
      assert_equal 2, appends
    end

    def test_a_failure_waits_for_the_chunks_already_begun
      stub_failing_first_append(failure_wait: 0.01, success_wait: 0.05)

      assert_raises(BadRequest) { upload(chunks: 2, concurrency: 2) }
      assert_equal 1, @finished.size
    end

    def test_raises_the_error_of_the_chunk_that_failed_first
      stub_failing_first_append(failure_wait: 0.01, success_wait: 0.05, success_status: 403)

      assert_raises(BadRequest) { upload(chunks: 2, concurrency: 2) }
    end

    private

    # Fail the first chunk with 400 Bad Request, and answer every other after a longer wait
    def stub_failing_first_append(failure_wait:, success_wait:, success_status: 204)
      @finished = []
      stub_request(:post, APPEND_URL).to_return do |request|
        failed = request.body.b.include?("name=\"segment_index\"\r\n\r\n0\r\n")
        sleep(failed ? failure_wait : success_wait)
        @finished << request unless failed
        {status: failed ? 400 : success_status}
      end
    end

    def appends
      WebMock::RequestRegistry.instance.times_executed(WebMock::RequestPattern.new(:post, APPEND_URL))
    end

    def stub_slow_appends
      stub_request(:post, APPEND_URL).to_return do
        @lock.synchronize { @most_active = [@most_active, @active += 1].max }
        sleep 0.02
        @lock.synchronize { @active -= 1 }
        {status: 204}
      end
    end

    def upload(chunks:, **)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.binwrite(path, "\x01".b * (chunks * CHUNK_BYTES))
        Uploader::Media.chunked_upload(path, client: @client, media_category: "tweet_video",
          chunk_size_mb: CHUNK_BYTES / Uploader::Media::BYTES_PER_MB.to_f, **)
      end
    end
  end
end
