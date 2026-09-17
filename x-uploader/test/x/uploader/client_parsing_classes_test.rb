require_relative "../../test_helper"

module X
  # A parsing class a client can default to, which the uploaders must never use
  class RefusedObject
    def self.new(*) = raise("the uploaders parsed a response with the client's default_object_class")
  end

  class ClientParsingClassesTest < Minitest::Test
    cover Uploader::Account
    cover Uploader::Chunks
    cover Uploader::Media
    cover Uploader::Metadata

    UPLOAD_URL = "https://api.x.com/2/media/upload".freeze
    JSON_RESPONSE = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}.freeze

    def setup
      @client = Client.new(**test_oauth_credentials, default_object_class: RefusedObject, default_array_class: RefusedObject)
    end

    def test_upload_an_image
      stub_request(:post, UPLOAD_URL).to_return(JSON_RESPONSE)

      assert_equal(Uploader::UploadedMedia.new({"id" => TEST_MEDIA_ID}), Uploader::Media.upload("test/sample_files/sample.png", client: @client))
    end

    def test_upload_a_video_in_chunks_and_await_processing
      processing = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "pending"}}}.to_json}
      stub_request(:post, "#{UPLOAD_URL}/initialize").to_return(JSON_RESPONSE)
      stub_request(:post, "#{UPLOAD_URL}/#{TEST_MEDIA_ID}/append").to_return(JSON_RESPONSE)
      stub_request(:post, "#{UPLOAD_URL}/#{TEST_MEDIA_ID}/finalize").to_return(processing)
      stub_request(:get, "#{UPLOAD_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}")
        .to_return(headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID, processing_info: {state: "succeeded"}}}.to_json)

      assert_equal "succeeded", Uploader::Media.upload("test/sample_files/sample.mp4", client: @client).dig("processing_info", "state")
    end

    def test_add_alt_text_and_subtitles
      stub_request(:post, "https://api.x.com/2/media/metadata").to_return(JSON_RESPONSE)
      stub_request(:post, "https://api.x.com/2/media/subtitles").to_return(JSON_RESPONSE)

      assert_equal({"id" => TEST_MEDIA_ID}, Uploader::Metadata.add_alt_text(TEST_MEDIA_ID, "A cat", client: @client))
      assert_equal({"id" => TEST_MEDIA_ID}, Uploader::Metadata.add_subtitles(TEST_MEDIA_ID, "1", "EN", client: @client))
    end

    def test_update_profile_image_and_banner
      user = {headers: {"content-type" => "application/json"}, body: {id: 1, entities: [1]}.to_json}
      stub_request(:post, "https://api.x.com/1.1/account/update_profile_image.json").to_return(user)
      stub_request(:post, "https://api.x.com/1.1/account/update_profile_banner.json").to_return(user)

      assert_equal({"id" => 1, "entities" => [1]}, Uploader::Account.update_profile_image("test/sample_files/sample.png", client: @client))
      assert_equal({"id" => 1, "entities" => [1]}, Uploader::Account.update_profile_banner("test/sample_files/sample.png", client: @client))
    end
  end
end
