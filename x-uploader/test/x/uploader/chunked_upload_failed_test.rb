# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ChunkedUploadFailedTest < Minitest::Test
    cover ChunkedUploadFailed

    def test_holds_the_media_it_was_given_as_uploaded_media_and_names_it_with_the_reason_it_failed
      failure = Class.new(Error) { def message = "Service Unavailable" }
      error = assert_raises(ChunkedUploadFailed) { ChunkedUploadFailed.__send__(:keeping, {"id" => "7"}) { raise failure } }

      assert_equal [UploadedMedia.new({"id" => "7"}), 7], [error.media, error.media.id]
      assert_equal ["Media 7 was initialized, but its upload could not be finished: Service Unavailable"] * 2, [error.message, error.to_s]
      assert_kind_of Uploader::Error, error
    end

    def test_holds_uploaded_media_given_as_it_was_given
      media = UploadedMedia.new({"id" => "7"})

      assert_same media, ChunkedUploadFailed.new(media:).media
    end

    def test_holds_media_given_as_a_subclass_of_hash_as_uploaded_media
      media = Class.new(Hash).new.merge!("id" => "7")

      assert_instance_of UploadedMedia, ChunkedUploadFailed.new(media:).media
    end

    def test_names_the_media_alone_without_a_cause
      assert_equal "Media 7 was initialized, but its upload could not be finished", ChunkedUploadFailed.new(media: {"id" => "7"}).message
    end

    def test_takes_a_message_of_its_own_as_a_test_stub_raises_it
      error = assert_raises(ChunkedUploadFailed) { raise ChunkedUploadFailed, "The upload could not be finished" }

      assert_equal ["The upload could not be finished", nil], [error.message, error.media]
    end

    def test_names_no_media_when_given_none_or_media_that_holds_no_identifier
      assert_equal ["Media was initialized, but its upload could not be finished"] * 2,
        [ChunkedUploadFailed.new, ChunkedUploadFailed.new(media: {})].map(&:message)
    end

    def test_a_message_of_its_own_ends_with_the_reason_it_failed
      error = assert_raises(ChunkedUploadFailed) do
        raise Error, "Connection reset"
      rescue Error
        raise ChunkedUploadFailed.new("Unfinished", media: {"id" => "7"})
      end

      assert_equal ["Unfinished: Connection reset", 7], [error.message, error.media.id]
    end

    def test_keeping_is_private
      refute_respond_to ChunkedUploadFailed, :keeping
    end

    def test_keeping_returns_what_the_block_returns_and_raises_what_is_not_an_error_of_the_api
      assert_equal 1, ChunkedUploadFailed.__send__(:keeping, {}) { 1 }
      assert_raises(ArgumentError) { ChunkedUploadFailed.__send__(:keeping, {}) { raise ArgumentError } }
    end
  end

  class ChunkedUploadFailedUploadTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Chunks)

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      stub_request(:post, "#{BASE_URL}/initialize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID, media_key: "7_#{TEST_MEDIA_ID}"}}.to_json)
      @finalize = "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize"
    end

    def upload = Uploader::MediaUpload.chunked_upload("test/sample_files/sample.mp4", client: Client.new, media_category: "tweet_video")

    def test_a_chunk_that_fails_raises_with_the_media_the_upload_initialized
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 400)
      error = assert_raises(ChunkedUploadFailed) { upload }

      assert_equal [TEST_MEDIA_ID.to_i, "7_#{TEST_MEDIA_ID}", BadRequest], [error.media.id, error.media.media_key, error.cause.class]
      assert_not_requested :post, @finalize
    end

    def test_a_finalize_that_fails_raises_with_the_media_the_upload_initialized
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, @finalize).to_return(status: 403)
      error = assert_raises(ChunkedUploadFailed) { upload }

      assert_equal [TEST_MEDIA_ID.to_i, Forbidden], [error.media.id, error.cause.class]
    end
  end
end
