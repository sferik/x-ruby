require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaUploadOptionsTest < Minitest::Test
    cover Uploader::Media

    def setup
      @client = Client.new
    end

    def test_upload_passes_the_chunk_options_to_the_chunked_upload
      options = chunk_options_of(media_type: "video/webm", chunk_size_mb: 2, concurrency: 3)

      assert_equal({media_category: "tweet_video", media_type: "video/webm", chunk_size_mb: 2, concurrency: 3}, options)
    end

    def test_upload_passes_the_default_chunk_options_to_the_chunked_upload
      assert_equal({media_category: "tweet_video", media_type: nil, chunk_size_mb: 1, concurrency: 4}, chunk_options_of)
    end

    private

    def chunk_options_of(**)
      options = nil
      Uploader::Media.stub(:chunked_upload, ->(*, **kwargs) { options = kwargs.except(:client) }) do
        Uploader::Media.upload("test/sample_files/sample.mp4", client: @client, **)
      end
      options
    end
  end
end
