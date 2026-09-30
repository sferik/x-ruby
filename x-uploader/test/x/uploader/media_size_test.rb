# frozen_string_literal: true

require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  # Media larger than the API takes of its category, whatever the account, is refused before a request
  class MediaSizeTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Validator)

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze
    MB = Uploader::MediaUpload.const_get(:BYTES_PER_MB)
    LIMITS = {"tweet_image" => 5 * MB, "dm_image" => 5 * MB, "tweet_gif" => 15 * MB, "dm_gif" => 15 * MB, "subtitles" => MB}.freeze

    def setup
      @client = Client.new
    end

    def test_each_category_takes_media_of_its_limit_and_refuses_a_byte_more
      LIMITS.each do |category, limit|
        with_file("media.bin", limit) { |path| assert_nil validator.validate_size!(source(path), category) }
        with_file("media.bin", limit + 1) do |path|
          error = assert_raises(InvalidMedia, category) { validator.validate_size!(source(path), category) }

          assert_equal "#{path} is #{limit + 1} bytes, more than the #{limit} bytes the API takes of #{category} media", error.message
        end
      end
    end

    def test_a_video_of_any_size_is_left_to_the_api
      with_file("clip.mp4", 600 * MB) do |path|
        %w[tweet_video dm_video amplify_video].each { |category| assert_nil validator.validate_size!(source(path), category) }
      end
    end

    def test_an_image_larger_than_the_api_takes_uploads_nothing
      with_file("cat.png", (5 * MB) + 1) do |path|
        assert_raises(InvalidMedia) { Uploader::MediaUpload.upload(path, client: @client) }
        assert_raises(InvalidMedia) { Uploader::MediaUpload.upload(path, client: @client, media_category: :dm_image) }
      end
      assert_raises(InvalidMedia) { Uploader::MediaUpload.upload_binary("\x00".b * ((5 * MB) + 1), client: @client, media_category: "tweet_image") }
      assert_not_requested :any, /x\.com/
    end

    def test_binary_content_larger_than_a_single_request_takes_uploads_nothing
      gif = "GIF89a".b + ("\x00".b * ((5 * MB) - 5))
      error = assert_raises(InvalidMedia) { Uploader::MediaUpload.upload_binary(gif, client: @client, media_category: :tweet_gif) }

      assert_equal "the media given is #{(5 * MB) + 1} bytes, more than the #{5 * MB} bytes the API takes in a single request: pass it to upload or chunked_upload", error.message
      assert_not_requested :any, /x\.com/
    end

    def test_binary_content_larger_than_the_api_takes_of_its_category_is_refused_for_that
      error = assert_raises(InvalidMedia) { Uploader::MediaUpload.upload_binary("\x00".b * ((15 * MB) + 1), client: @client, media_category: :dm_gif) }

      assert_equal "the media given is #{(15 * MB) + 1} bytes, more than the #{15 * MB} bytes the API takes of dm_gif media", error.message
    end

    def test_binary_content_of_as_much_as_a_single_request_takes_uploads
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: '{"data":{"id":"1"}}')

      assert_equal 1, Uploader::MediaUpload.upload_binary("GIF89a".b.ljust(5 * MB, "\x00"), client: @client, media_category: :dm_gif).media_id
    end

    def test_empty_binary_content_uploads_nothing
      error = assert_raises(InvalidMedia) { Uploader::MediaUpload.upload_binary("", client: @client, media_category: :tweet_image) }

      assert_equal "the media given is empty: there is nothing to upload", error.message
      assert_not_requested :any, /x\.com/
    end

    def test_a_gif_or_subtitles_larger_than_the_api_takes_upload_nothing
      with_file("cat.gif", (15 * MB) + 1) do |path|
        assert_raises(InvalidMedia) { Uploader::MediaUpload.upload(path, client: @client, media_category: :tweet_gif) }
        assert_raises(InvalidMedia) { Uploader::MediaUpload.chunked_upload(path, client: @client, media_category: :dm_gif) }
      end
      with_file("cat.srt", MB + 1) { |path| assert_raises(InvalidMedia) { Uploader::MediaUpload.chunked_upload(path, client: @client) } }
      assert_not_requested :any, /x\.com/
    end

    def test_a_gif_larger_than_any_the_api_takes_is_refused_without_being_read
      with_file("cat.gif", (15 * MB) + 1) do |path|
        error = Uploader.const_get(:Gif).stub(:animated?, ->(_media) { flunk "the GIF was read" }) do
          assert_raises(InvalidMedia) { Uploader::MediaUpload.upload(path, client: @client) }
        end

        assert_equal "#{path} is #{(15 * MB) + 1} bytes, more than the #{15 * MB} bytes the API takes of tweet_gif media", error.message
      end
    end

    def test_a_still_gif_the_api_takes_as_a_gif_is_read_and_refused_as_an_image
      with_file("cat.gif", 15 * MB) do |path|
        error = assert_raises(InvalidMedia) { Uploader::MediaUpload.upload(path, client: @client) }

        assert_equal "#{path} is #{15 * MB} bytes, more than the #{5 * MB} bytes the API takes of tweet_image media", error.message
      end
    end

    def test_media_that_is_not_there_raises_for_that_before_its_size_is_read
      error = assert_raises(Errno::ENOENT) do
        validator.validate_upload!(source("nope.png"), "tweet_image", alt_text: nil, chunk_size: nil, concurrency: 1, processing_timeout: 1)
      end

      assert_equal "No such file or directory - nope.png", error.message
    end

    private

    def validator = Uploader.const_get(:Validator)

    # The media an upload reads, which the validator takes in place of a path
    def source(file_path) = Uploader.const_get(:Source).for(file_path)

    # A sparse file of a size, which costs no disk of its own
    def with_file(name, size)
      Dir.mktmpdir do |dir|
        path = File.join(dir, name)
        File.write(path, name.end_with?(".gif") ? "GIF89a" : "")
        File.truncate(path, size)
        yield path
      end
    end
  end
end
