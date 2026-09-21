# frozen_string_literal: true

require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaGifTest < Minitest::Test
    cover Uploader::MediaUpload

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze
    MAX_SIMPLE = Uploader::MediaUpload::MAX_SIMPLE_UPLOAD_BYTES

    def setup
      @client = Client.new
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "#{BASE_URL}/initialize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
    end

    def test_a_gif_no_larger_than_a_single_request_takes_uploads_whole
      with_gif(MAX_SIMPLE) { |path| Uploader::MediaUpload.upload(path, client: @client, media_category: "tweet_gif") }

      assert_requested :post, BASE_URL
      assert_not_requested :post, "#{BASE_URL}/initialize"
    end

    def test_a_gif_larger_than_a_single_request_takes_uploads_in_chunks
      with_gif(MAX_SIMPLE + 1) { |path| Uploader::MediaUpload.upload(path, client: @client, media_category: "tweet_gif") }

      assert_requested :post, "#{BASE_URL}/initialize", body: {media_type: "image/gif", media_category: "tweet_gif", total_bytes: MAX_SIMPLE + 1}.to_json
      assert_not_requested :post, BASE_URL
    end

    def test_a_direct_message_gif_larger_than_a_single_request_takes_uploads_in_chunks
      with_gif(MAX_SIMPLE + 1) { |path| Uploader::MediaUpload.upload(path, client: @client, media_category: "dm_gif") }

      assert_requested :post, "#{BASE_URL}/initialize", body: {media_type: "image/gif", media_category: "dm_gif", total_bytes: MAX_SIMPLE + 1}.to_json
    end

    def test_a_small_animated_gif_of_its_own_category_uploads_whole
      Uploader::MediaUpload.upload("test/sample_files/sample_animated.gif", client: @client)

      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"media_category\"\r\n\r\ntweet_gif") }
    end

    def test_a_gif_uploads_in_chunks_only_once_a_single_request_cannot_take_it
      with_gif(MAX_SIMPLE) do |path|
        assert_equal [false, false], %w[tweet_gif dm_gif].map { |category| Uploader::MediaUpload.chunked_upload?(path, category) }
      end
      with_gif(MAX_SIMPLE + 1) do |path|
        assert_equal [true, true], %w[tweet_gif dm_gif].map { |category| Uploader::MediaUpload.chunked_upload?(path, category) }
      end
    end

    def test_a_video_and_subtitles_upload_in_chunks_whatever_their_size
      assert_equal [true] * 4, %w[amplify_video dm_video tweet_video subtitles].map { |category| Uploader::MediaUpload.chunked_upload?("nope.mp4", category) }
    end

    def test_an_image_uploads_whole_whatever_its_size
      with_gif(MAX_SIMPLE + 1) do |path|
        assert_equal [false, false], %w[tweet_image dm_image].map { |category| Uploader::MediaUpload.chunked_upload?(path, category) }
      end
    end

    def test_the_category_of_a_chunked_upload_is_read_in_any_case
      assert_equal [true, true, false], [Uploader::MediaUpload.chunked_upload?("nope.mp4", :TWEET_VIDEO),
        Uploader::MediaUpload.chunked_upload?("nope.mp4", "Tweet_Video"), Uploader::MediaUpload.chunked_upload?("test/sample_files/sample_animated.gif", :TWEET_GIF)]
    end

    private

    # A sparse file of a size, which costs no disk of its own
    def with_gif(size)
      Dir.mktmpdir do |dir|
        path = File.join(dir, "cat.gif")
        File.write(path, "")
        File.truncate(path, size)
        yield path
      end
    end
  end
end
