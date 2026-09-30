# frozen_string_literal: true

require "stringio"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaTypeSignatureTest < Minitest::Test
    cover Uploader::MediaUpload

    PNG = File.binread("test/sample_files/sample.png").freeze
    TRANSPORT_STREAM = (("G" + ("\xFF" * 187)) * 3).b.freeze
    TYPE_CATEGORY = {"video/mp4" => "tweet_video", "video/quicktime" => "dm_video", "text/srt" => "subtitles", "video/webm" => "amplify_video"}.freeze

    def test_every_type_whose_files_all_begin_with_a_signature_is_checked_for_it
      %w[bmp gif jpg jpeg pjpeg png tif webp vtt ts m2ts].each do |extension|
        in_file("media.#{extension}", "not media at all") do |path|
          assert_raises(InvalidMediaType, extension) { inference.infer_media_category(path) }
        end
      end
    end

    def test_a_file_named_as_a_type_that_may_begin_with_no_signature_is_typed_by_its_name
      {"mp4" => "video/mp4", "m4v" => "video/mp4", "mov" => "video/quicktime", "srt" => "text/srt", "webm" => "video/webm"}.each do |extension, type|
        in_file("media.#{extension}", "\x00\x00\x00\x08wide".b) do |path|
          assert_equal type, inference.infer_media_type(path, TYPE_CATEGORY.fetch(type)), extension
        end
      end
    end

    def test_the_bytes_of_media_name_its_type_before_the_name_of_its_file
      in_file("media.gif", PNG) do |path|
        assert_equal "tweet_image", inference.infer_media_category(path)
        assert_equal "image/png", inference.infer_media_type(path, "tweet_image")
      end
      in_file("media.srt", TRANSPORT_STREAM) do |path|
        assert_equal "tweet_video", inference.infer_media_category(path)
        assert_equal "video/mp2t", inference.infer_media_type(path, "dm_video")
      end
    end

    def test_a_file_that_cannot_be_read_is_typed_by_its_name
      Dir.mktmpdir do |dir|
        path = File.join(dir, "folder.png")
        Dir.mkdir(path)

        assert_equal "image/png", inference.infer_media_type(path, "tweet_image")
      end
    end

    def test_media_of_no_known_type_uploads_in_chunks_as_the_first_type_of_a_video_or_subtitles_category
      in_file("media", "\x00\x00\x00\x08wide".b) do |path|
        assert_equal %w[video/mp4 video/mp4 video/mp4 text/srt], %w[tweet_video dm_video amplify_video subtitles].map { |category| inference.infer_media_type(path, category) }
      end
    end

    def test_media_of_a_type_its_category_does_not_take_is_refused
      mp4 = StringIO.new(File.binread("test/sample_files/sample.mp4"))
      error = assert_raises(InvalidMediaType) { inference.infer_media_type(mp4, "subtitles") }

      assert_match(/\Athe media given is video\/mp4, which subtitles media is not: /, error.message)
    end

    def test_infer_media_category_refuses_a_file_whose_name_names_no_type
      %w[a.unknown a].each do |file|
        error = assert_raises(InvalidMediaType) { inference.infer_media_category(file) }

        assert_equal "unable to determine the media type of #{file}: pass media_category", error.message
      end
    end

    private

    def in_file(name, content)
      Dir.mktmpdir do |dir|
        path = File.join(dir, name)
        File.binwrite(path, content)
        yield path
      end
    end
  end
end
