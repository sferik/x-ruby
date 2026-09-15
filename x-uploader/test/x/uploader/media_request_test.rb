require "fileutils"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaRequestTest < Minitest::Test
    cover Uploader::Media

    UPLOAD_URL = "https://api.twitter.com/2/media/upload".freeze
    BOUNDARY = "AaB03x".freeze
    CONTENT = "\x89PNG\r\n\x1A\n\x00\x00\x00...".b.freeze
    GIF_FILE = "test/sample_files/sample.gif".freeze
    HEX_BOUNDARY = %r{\Amultipart/form-data; boundary=(\h{32})\z}

    def setup
      @client = Client.new
      stub_request(:post, UPLOAD_URL).to_return do |request|
        @request = request
        {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}
      end
    end

    def test_upload_binary_body_and_headers
      Uploader::Media.upload_binary(CONTENT, "tweet_image", client: @client, boundary: BOUNDARY)

      assert_equal "multipart/form-data; boundary=#{BOUNDARY}", @request.headers["Content-Type"]
      assert_equal upload_body(CONTENT, "tweet_image", BOUNDARY), @request.body.b
    end

    def test_upload_sends_file_content
      Uploader::Media.upload(GIF_FILE, client: @client, media_category: "tweet_gif", boundary: BOUNDARY)

      assert_equal upload_body(File.binread(GIF_FILE), "tweet_gif", BOUNDARY), @request.body.b
    end

    def test_upload_binary_default_boundary
      Uploader::Media.upload_binary(CONTENT, "tweet_image", client: @client)

      assert_equal upload_body(CONTENT, "tweet_image", request_boundary), @request.body.b
    end

    def test_upload_default_boundary
      Uploader::Media.upload(GIF_FILE, client: @client, media_category: "tweet_gif")

      assert_equal upload_body(File.binread(GIF_FILE), "tweet_gif", request_boundary), @request.body.b
    end

    def test_upload_binary_rejects_invalid_category_before_requesting
      assert_raises(ArgumentError) { Uploader::Media.upload_binary(CONTENT, "bogus", client: @client) }
      assert_not_requested(:post, UPLOAD_URL)
    end

    def test_upload_rejects_missing_file_before_reading_it
      error = assert_raises(RuntimeError) { Uploader::Media.upload("nope.jpg", client: @client, media_category: "tweet_image") }

      assert_equal "File not found: nope.jpg", error.message
    end

    private

    def request_boundary
      match = HEX_BOUNDARY.match(@request.headers["Content-Type"])

      refute_nil match, "Expected a random hex boundary in #{@request.headers["Content-Type"].inspect}"
      match[1]
    end

    def upload_body(content, media_category, boundary)
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"media_category\"\r\n\r\n#{media_category}\r\n" \
        "--#{boundary}\r\nContent-Disposition: form-data; name=\"media\"\r\n" \
        "Content-Type: application/octet-stream\r\n\r\n#{content}\r\n--#{boundary}--\r\n".b
    end
  end
end
