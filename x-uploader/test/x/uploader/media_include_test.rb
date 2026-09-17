require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaIncludeTest < Minitest::Test
    cover Uploader::Media

    BASE_URL = "https://api.x.com/2/media/upload".freeze

    # A class of a caller's own that includes the uploader
    class MediaUploader
      include X::Uploader::Media
    end

    def test_a_class_that_includes_media_uploads_in_chunks
      json = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}
      stub_request(:post, "#{BASE_URL}/initialize").to_return(json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(json)

      media = MediaUploader.new.chunked_upload("test/sample_files/sample.mp4", client: Client.new, media_category: "tweet_video")

      assert_equal TEST_MEDIA_ID, media["id"]
    end
  end
end
