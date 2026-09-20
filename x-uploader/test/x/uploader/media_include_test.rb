# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader"

module X
  class MediaIncludeTest < Minitest::Test
    cover Uploader::Media
    cover Uploader::Account
    cover Uploader::Metadata

    BASE_URL = "https://api.x.com/2/media/upload"
    JSON = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}.freeze

    # A class of a caller's own that includes the uploader
    class MediaUploader
      include X::Uploader::Media
    end

    # A class whose own methods have the names of what the uploaders call internally, none of which takes an argument
    class Attachment
      include X::Uploader::Media
      include X::Uploader::Account
      include X::Uploader::Metadata

      %i[init append await transfer extension chunked? still_gif? upload_chunk chunk_queue append_worker media_id v1_client
        validate_file! body headers construct_upload_body construct_multipart_body construct_banner_body multipart_field].each do |name|
        define_method(name) { raise "#{name} is the caller's own method" }
      end
    end

    def test_a_class_that_includes_media_uploads_in_chunks
      stub_chunked_upload
      media = MediaUploader.new.chunked_upload("test/sample_files/sample.mp4", client: Client.new, media_category: "tweet_video")

      assert_equal TEST_MEDIA_ID.to_i, media["id"]
    end

    def test_a_class_with_methods_of_its_own_uploads_a_video
      stub_chunked_upload
      media = Attachment.new.upload("test/sample_files/sample.mp4", client: Client.new)

      assert_equal TEST_MEDIA_ID.to_i, media["id"]
      assert_requested(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append")
    end

    def test_a_class_with_methods_of_its_own_uploads_an_image_and_describes_it
      stub_request(:post, BASE_URL).to_return(JSON)
      stub_request(:post, "https://api.x.com/2/media/metadata").to_return(status: 204)
      media = Attachment.new.upload("test/sample_files/sample.gif", client: Client.new, alt_text: "A cat")

      assert_equal TEST_MEDIA_ID.to_i, media["id"]
      assert_requested(:post, "https://api.x.com/2/media/metadata", body: {id: TEST_MEDIA_ID, metadata: {alt_text: {text: "A cat"}}}.to_json)
    end

    def test_a_class_with_methods_of_its_own_awaits_processing_and_infers_a_media_type
      stub_request(:get, "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}").to_return(JSON)
      attachment = Attachment.new

      assert_equal TEST_MEDIA_ID.to_i, attachment.await_processing!({"id" => TEST_MEDIA_ID}, client: Client.new)["id"]
      assert_equal "video/webm", attachment.infer_media_type("clip.webm", "tweet_video")
    end

    def test_a_class_with_methods_of_its_own_updates_a_profile_image_and_banner
      stub_request(:post, %r{\Ahttps://api\.x\.com/1\.1/account/}).to_return(status: 200)
      attachment = Attachment.new
      attachment.update_profile_image("test/sample_files/sample.png", client: Client.new(**test_oauth_credentials))
      attachment.update_profile_banner("test/sample_files/sample.png", client: Client.new(**test_oauth_credentials), width: 1500)

      assert_requested(:post, "https://api.x.com/1.1/account/update_profile_image.json")
      assert_requested(:post, "https://api.x.com/1.1/account/update_profile_banner.json")
    end

    def test_a_class_with_methods_of_its_own_adds_subtitles
      stub_request(:post, "https://api.x.com/2/media/subtitles").to_return(status: 204)
      Attachment.new.add_subtitles(7, {"id" => 8}, "en", client: Client.new)

      assert_requested(:post, "https://api.x.com/2/media/subtitles", body: {id: "7", media_category: "TweetVideo", subtitles: {id: "8", language_code: "EN"}}.to_json)
    end

    def test_a_class_that_includes_an_uploader_gains_its_public_methods_alone
      [Uploader::Media, Uploader::Account, Uploader::Metadata].each do |uploader|
        assert_empty uploader.private_instance_methods(false), "Expected #{uploader} to define no private methods"
        assert_empty uploader.ancestors - [uploader], "Expected #{uploader} to include no other module"
      end
    end

    private

    def stub_chunked_upload
      stub_request(:post, "#{BASE_URL}/initialize").to_return(JSON)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(JSON)
    end
  end
end
