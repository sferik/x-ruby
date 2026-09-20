# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/multipart"

module X
  class MultipartTest < Minitest::Test
    cover Uploader.const_get(:Multipart)

    FILE_PART = "--b\r\nContent-Disposition: form-data; name=\"media\"\r\n" \
      "Content-Type: application/octet-stream\r\n\r\ncontent\r\n--b--\r\n"

    def test_headers_name_the_boundary
      assert_equal({"Content-Type" => "multipart/form-data; boundary=b"}, Uploader.const_get(:Multipart).headers("b"))
    end

    def test_body_holds_the_content
      assert_equal FILE_PART, Uploader.const_get(:Multipart).body("media", "content", boundary: "b")
    end

    def test_body_holds_each_field_before_the_content
      fields = "--b\r\nContent-Disposition: form-data; name=\"segment_index\"\r\n\r\n0\r\n" \
        "--b\r\nContent-Disposition: form-data; name=\"media_category\"\r\n\r\ntweet_video\r\n"

      assert_equal fields + FILE_PART, Uploader.const_get(:Multipart).body("media", "content", boundary: "b", segment_index: 0, media_category: "tweet_video")
    end

    def test_body_leaves_out_a_field_that_is_nil
      assert_equal FILE_PART, Uploader.const_get(:Multipart).body("media", "content", boundary: "b", width: nil)
    end

    def test_body_of_binary_content_is_binary
      content = "\xFF\xD8\xFF".b
      body = Uploader.const_get(:Multipart).body("media", content, boundary: "b", segment_index: 1)

      assert_equal Encoding::BINARY, body.encoding
      assert_includes body, "\r\n\r\n#{content}\r\n".b
    end
  end
end
