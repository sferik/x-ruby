# frozen_string_literal: true

require "timeout"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  # An upload stopped as a chunk stores the tokens of a refresh it made waits for save_tokens, rather than leave the
  # store with a refresh token X no longer accepts, and one whose save_tokens raises raises with the tokens
  class MediaChunkRefreshTest < Minitest::Test
    cover Uploads.const_get(:Chunks)

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}.freeze

    def setup
      stub_request(:post, "#{BASE_URL}/initialize").to_return(JSON)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return({status: 401}, {status: 204})
      stub_request(:post, "https://api.x.com/2/oauth2/token")
        .to_return(status: 200, body: {access_token: "NEW_ACCESS_TOKEN", refresh_token: "NEW_REFRESH_TOKEN"}.to_json)
    end

    def test_an_upload_stopped_as_a_chunk_stores_the_tokens_of_its_refresh_waits_for_them_to_be_stored
      saved = []
      saving = Thread::Queue.new
      uploader = uploading(oauth2_client(->(tokens) { saving << true && sleep(0.2) && saved << tokens.refresh_token }))
      saving.pop(timeout: 5)
      uploader.raise(Interrupt)

      assert_raises(Interrupt) { uploader.join }
      assert_equal ["NEW_REFRESH_TOKEN"], saved
    end

    def test_a_timeout_of_the_save_tokens_of_a_chunk_still_ends_it
      client = oauth2_client(->(_tokens) { Timeout.timeout(0.05) { sleep 2 } })
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      error = assert_raises(TokenReportFailed) { upload(client) }

      assert_equal "NEW_REFRESH_TOKEN", error.tokens.refresh_token
      assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 1
    end

    def test_a_chunk_whose_save_tokens_raises_raises_with_the_tokens_rather_than_the_media
      error = assert_raises(TokenReportFailed) { upload(oauth2_client(->(_tokens) { raise "Store is down" })) }

      assert_equal ["NEW_REFRESH_TOKEN", "#<RuntimeError: Store is down>"], [error.tokens.refresh_token, error.cause.inspect]
    end

    private

    def oauth2_client(save_tokens)
      Client.new(client_id: "CLIENT_ID", access_token: "ACCESS_TOKEN", refresh_token: "REFRESH_TOKEN", save_tokens:)
    end

    def uploading(client)
      Thread.new { upload(client) }.tap { |thread| thread.report_on_exception = false }
    end

    def upload(client)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.binwrite(path, "\x01".b * 1024)
        Uploads::MediaUpload.chunked_upload(path, client:, media_category: "tweet_video", chunk_size: 1024)
      end
    end
  end
end
