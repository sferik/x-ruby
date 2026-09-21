# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader"

module X
  class MediaPathnameTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader::Account
    cover Uploader.const_get(:Chunks)

    UPLOAD_URL = "https://api.x.com/2/media/upload"
    JSON = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}.freeze

    def setup
      @client = Client.new
    end

    def test_upload_of_an_image_at_a_pathname
      stub_request(:post, UPLOAD_URL).to_return(JSON)

      assert_equal TEST_MEDIA_ID.to_i, Uploader::MediaUpload.upload(Pathname("test/sample_files/sample.png"), client: @client)["id"]
    end

    def test_upload_of_a_video_at_a_pathname
      %W[initialize #{TEST_MEDIA_ID}/finalize].each { |path| stub_request(:post, "#{UPLOAD_URL}/#{path}").to_return(JSON) }
      stub_request(:post, "#{UPLOAD_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      path = Pathname("test/sample_files/sample.mp4")

      assert_equal TEST_MEDIA_ID.to_i, Uploader::MediaUpload.upload(path, client: @client)["id"]
      assert_requested(:post, "#{UPLOAD_URL}/initialize", body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: path.size}.to_json)
    end

    def test_a_missing_pathname_raises_the_error_of_a_missing_file
      [-> { Uploader::MediaUpload.upload(Pathname("nope.png"), client: @client) },
        -> { Uploader::MediaUpload.chunked_upload(Pathname("nope.mp4"), client: @client) },
        -> { Uploader::Account.update_profile_image(Pathname("nope.png"), client: @client) },
        -> { Uploader::Account.update_profile_banner(Pathname("nope.png"), client: @client) }].each do |upload|
        assert_match(/\ANo such file or directory - nope\.(png|mp4)\z/, assert_raises(Errno::ENOENT, &upload).message)
      end
    end

    def test_infers_the_category_and_type_of_a_pathname
      assert_equal "tweet_gif", Uploader::MediaUpload.infer_media_category(Pathname("test/sample_files/sample_animated.gif"))
      assert_equal "tweet_image", Uploader::MediaUpload.infer_media_category(Pathname("test/sample_files/sample.gif"))
      assert_equal "video/quicktime", Uploader::MediaUpload.infer_media_type(Pathname("clip.mov"), "tweet_video")
    end

    def test_update_profile_image_and_banner_at_a_pathname
      stub_request(:post, %r{\Ahttps://api\.x\.com/1\.1/account/}).to_return(status: 200)
      client = Client.new(**test_oauth_credentials)
      Uploader::Account.update_profile_image(Pathname("test/sample_files/sample.png"), client:)
      Uploader::Account.update_profile_banner(Pathname("test/sample_files/sample.png"), client:)

      assert_requested(:post, "https://api.x.com/1.1/account/update_profile_image.json")
      assert_requested(:post, "https://api.x.com/1.1/account/update_profile_banner.json")
    end
  end
end
