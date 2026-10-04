# frozen_string_literal: true

require "stringio"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  class MediaTypeCheckTest < Minitest::Test
    cover Uploads::MediaUpload

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze
    PNG = File.binread("test/sample_files/sample.png").freeze

    def setup
      @client = Client.new
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
    end

    def test_a_small_video_uploaded_as_a_gif_is_refused_before_any_request
      error = assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload("test/sample_files/sample.mp4", client: @client, media_category: "tweet_gif") }

      assert_equal "test/sample_files/sample.mp4 is video/mp4, which tweet_gif media is not: pass the media_category of " \
        "what it is, or the media_type to send it as to chunked_upload", error.message
      assert_not_requested :any, /x\.com/
    end

    def test_a_video_uploaded_in_chunks_as_a_gif_or_as_subtitles_is_refused_before_any_request
      %w[tweet_gif dm_gif subtitles].each do |category|
        assert_raises(InvalidMediaType) { Uploads::MediaUpload.chunked_upload("test/sample_files/sample.mp4", client: @client, media_category: category) }
      end
      assert_not_requested :any, /x\.com/
    end

    def test_an_image_uploaded_as_a_video_is_refused_before_any_request
      error = assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload("test/sample_files/sample.png", client: @client, media_category: "tweet_video") }

      assert_match(/\Atest\/sample_files\/sample.png is image\/png, which tweet_video media is not/, error.message)
      assert_not_requested :any, /x\.com/
    end

    def test_a_media_type_given_to_a_chunked_upload_is_sent_whatever_the_media_is
      init = stub_request(:post, "#{BASE_URL}/initialize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      Uploads::MediaUpload.chunked_upload("test/sample_files/sample.png", client: @client, media_category: "tweet_video", media_type: "video/mp4")

      assert_requested init.with(body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: PNG.bytesize}.to_json)
    end

    def test_content_held_in_memory_of_a_type_its_category_does_not_take_is_refused_before_any_request
      error = assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload(StringIO.new(PNG), client: @client, media_category: "tweet_gif") }

      assert_match(/\Athe media given is image\/png, which tweet_gif media is not/, error.message)
      assert_not_requested :any, /x\.com/
    end

    def test_media_of_no_known_type_is_refused_as_a_gif
      [-> { Uploads::MediaUpload.upload(StringIO.new("not a gif"), client: @client, media_category: "dm_gif") },
        -> { Uploads::MediaUpload.upload(StringIO.new("not a gif"), client: @client, media_category: :TWEET_GIF) }].each do |upload|
        error = assert_raises(InvalidMediaType, &upload)

        assert_match(/\Athe media given is not a GIF, which (dm|tweet)_gif media must be\z/, error.message)
      end
      assert_not_requested :any, /x\.com/
    end

    def test_media_of_no_known_type_uploads_as_an_image_the_api_types_itself
      heic = "\x00\x00\x00\x18ftypheic\x00\x00\x00\x00mif1heic".b
      Uploads::MediaUpload.upload(StringIO.new(heic), client: @client, media_category: "tweet_image")
      Uploads::MediaUpload.upload(StringIO.new(heic), client: @client, media_category: "dm_image")

      assert_requested :post, BASE_URL, times: 2
    end

    def test_an_image_of_a_type_the_category_takes_uploads_in_a_single_request
      Uploads::MediaUpload.upload(StringIO.new(File.binread("test/sample_files/sample_animated.gif")), client: @client, media_category: "tweet_gif")
      Uploads::MediaUpload.upload("test/sample_files/sample.gif", client: @client, media_category: "tweet_image")

      assert_requested :post, BASE_URL, times: 2
    end

    def test_a_3d_model_is_refused_whatever_category_is_given
      in_file("model.glb", "glTF\x02\x00\x00\x00") do |path|
        error = assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload(path, client: @client, media_category: "tweet_image") }

        assert_equal "no media category the API documents takes a glTF 3D model, such as #{path}", error.message
      end
      assert_not_requested :any, /x\.com/
    end

    def test_a_file_named_as_a_type_whose_signature_it_does_not_begin_with_is_refused
      in_file("app.ts", "const answer: number = 42;\n") do |path|
        [-> { inference.infer_media_category(path) }, -> { inference.infer_media_type(path, "tweet_video") },
          -> { Uploads::MediaUpload.upload(path, client: @client, media_category: "tweet_image") }].each do |call|
          error = assert_raises(InvalidMediaType, &call)

          assert_equal "#{path} is named as video/mp2t, but does not begin with the bytes every video/mp2t file begins with", error.message
        end
      end

      assert_not_requested :any, /x\.com/
    end

    def test_a_file_of_no_known_type_is_refused_unless_its_category_is_given
      in_file("notes.pdf", "%PDF-1.7\n") do |path|
        error = assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload(path, client: @client) }

        assert_equal "unable to determine the media type of #{path}: pass media_category", error.message
        assert_not_requested :any, /x\.com/
        Uploads::MediaUpload.upload(path, client: @client, media_category: "tweet_image")
      end

      assert_requested :post, BASE_URL
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
