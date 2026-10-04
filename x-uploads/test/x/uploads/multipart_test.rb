# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/multipart"

module X
  class MultipartTest < Minitest::Test
    cover Uploads.const_get(:Multipart)

    UPLOAD_URL = "https://api.x.com/2/upload"

    FILE_PART = "--b\r\nContent-Disposition: form-data; name=\"media\"\r\n" \
      "Content-Type: application/octet-stream\r\n\r\ncontent\r\n--b--\r\n"

    def test_post_parses_the_response
      stub_request(:post, UPLOAD_URL).to_return(headers: {"content-type" => "application/json"}, body: '{"id":1}')

      assert_equal({"id" => 1}, Uploads.const_get(:Multipart).post(Client.new, "upload", "image", "content"))
    end

    def test_post_sends_the_body_with_the_boundary_its_headers_name
      stub_request(:post, UPLOAD_URL)
      Uploads.const_get(:Multipart).post(Client.new, "upload", "image", "content", width: 2)

      assert_requested(:post, UPLOAD_URL) do |request|
        boundary = request.headers["Content-Type"][/\Amultipart\/form-data; boundary=(\h+)\z/, 1]
        request.body.eql?(Uploads.const_get(:Multipart).body("image", "content", boundary:, width: 2))
      end
    end

    def test_each_post_has_a_boundary_of_its_own
      stub_request(:post, UPLOAD_URL)
      2.times { Uploads.const_get(:Multipart).post(Client.new, "upload", "image", "content") }
      content_types = []

      assert_requested(:post, UPLOAD_URL, times: 2) { |request| content_types << request.headers["Content-Type"] }
      assert_equal 2, content_types.uniq.size
    end

    def test_headers_name_the_boundary
      assert_equal({"Content-Type" => "multipart/form-data; boundary=b"}, Uploads.const_get(:Multipart).headers("b"))
    end

    def test_body_holds_the_content
      assert_equal FILE_PART, Uploads.const_get(:Multipart).body("media", "content", boundary: "b")
    end

    def test_body_holds_each_field_before_the_content
      fields = "--b\r\nContent-Disposition: form-data; name=\"segment_index\"\r\n\r\n0\r\n" \
        "--b\r\nContent-Disposition: form-data; name=\"media_category\"\r\n\r\ntweet_video\r\n"

      assert_equal fields + FILE_PART, Uploads.const_get(:Multipart).body("media", "content", boundary: "b", segment_index: 0, media_category: "tweet_video")
    end

    def test_body_leaves_out_a_field_that_is_nil
      assert_equal FILE_PART, Uploads.const_get(:Multipart).body("media", "content", boundary: "b", width: nil)
    end

    def test_body_of_binary_content_is_binary
      content = "\xFF\xD8\xFF".b
      body = Uploads.const_get(:Multipart).body("media", content, boundary: "b", segment_index: 1)

      assert_equal Encoding::BINARY, body.encoding
      assert_includes body, "\r\n\r\n#{content}\r\n".b
    end
  end
end
