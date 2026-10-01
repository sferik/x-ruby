# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaUploadOptionsTest < Minitest::Test
    cover Uploader::MediaUpload

    def setup
      @client = Client.new
    end

    def test_upload_passes_the_chunk_options_to_the_chunks
      options = chunk_options_of(media_type: "video/webm", chunk_size: 2_097_152, concurrency: 3, shared: true, additional_owners: [1])

      assert_equal({media_category: "tweet_video", media_type: "video/webm", chunk_size: 2_097_152, concurrency: 3, shared: true, additional_owners: [1]}, options)
    end

    def test_upload_passes_the_default_chunk_options_and_the_type_it_infers_to_the_chunks
      assert_equal({media_category: "tweet_video", media_type: "video/mp4", chunk_size: nil, concurrency: 4, shared: nil, additional_owners: nil}, chunk_options_of)
    end

    def test_the_default_concurrency_is_a_constant_of_media
      assert_equal [4, 16], [Uploader::MediaUpload::DEFAULT_CONCURRENCY, Uploader::MediaUpload::MAX_CONCURRENCY]
    end

    def test_the_limits_of_an_upload_are_constants
      assert_equal [1_048_576, 5_242_880], [Uploader::MediaUpload.const_get(:BYTES_PER_MB), Uploader::MediaUpload.const_get(:MAX_SIMPLE_UPLOAD_BYTES)]
      assert_equal [10_000, 1000], [Uploader.const_get(:Validator)::MAX_SEGMENTS, Uploader.const_get(:Validator)::MAX_ALT_TEXT_LENGTH]
    end

    def test_media_holds_none_of_the_constants_of_the_chunked_upload
      assert_equal %i[AMPLIFY_VIDEO DEFAULT_CONCURRENCY DEFAULT_PROCESSING_TIMEOUT DM_GIF DM_IMAGE DM_VIDEO MAX_CONCURRENCY SUBTITLES
        TWEET_GIF TWEET_IMAGE TWEET_VIDEO], Uploader::MediaUpload.constants.sort
      assert_empty Uploader.const_get(:Chunks).constants
    end

    def test_the_uploader_names_its_public_modules_alone
      assert_equal %i[API Account Error MediaUpload Metadata VERSION], Uploader.constants.sort
    end

    private

    def chunk_options_of(**)
      options = nil
      uploaded = UploadedMedia.new({"id" => TEST_MEDIA_ID})
      Uploader.const_get(:Chunks).stub(:upload, ->(**kwargs) { (options = kwargs.except(:client, :source)) && uploaded }) do
        Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: @client, **)
      end
      options
    end
  end
end
