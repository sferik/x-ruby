require_relative "../../test_helper"
require "x/uploader/account"

module X
  class AccountRequestTest < Minitest::Test
    cover Uploader::Account

    V1_URL = "https://api.x.com/1.1/account/".freeze
    V1_URL_PATTERN = /\A#{Regexp.escape(V1_URL)}/
    BOUNDARY = "AaB03x".freeze
    CONTENT = "\x89PNG\r\n\x1A\n\x00\x00\x00...".b.freeze
    PNG_FILE = "test/sample_files/sample.png".freeze
    HEX_BOUNDARY = %r{\Amultipart/form-data; boundary=(\h{32})\z}

    def setup
      @client = Client.new(**test_oauth_credentials)
      stub_request(:post, V1_URL_PATTERN).to_return do |request|
        @request = request
        {status: 200}
      end
    end

    def test_update_profile_image_binary_body
      Uploader::Account.update_profile_image_binary(CONTENT, client: @client, boundary: BOUNDARY)

      assert_equal "/1.1/account/update_profile_image.json", @request.uri.path
      assert_equal "multipart/form-data; boundary=#{BOUNDARY}", @request.headers["Content-Type"]
      assert_equal image_body(CONTENT, BOUNDARY), @request.body.b
    end

    def test_update_profile_image_sends_file_content
      Uploader::Account.update_profile_image(PNG_FILE, client: @client, boundary: BOUNDARY)

      assert_equal image_body(File.binread(PNG_FILE), BOUNDARY), @request.body.b
    end

    def test_update_profile_image_binary_default_boundary
      Uploader::Account.update_profile_image_binary(CONTENT, client: @client)

      assert_equal image_body(CONTENT, request_boundary), @request.body.b
    end

    def test_update_profile_image_default_boundary
      Uploader::Account.update_profile_image(PNG_FILE, client: @client)

      assert_equal image_body(File.binread(PNG_FILE), request_boundary), @request.body.b
    end

    def test_update_profile_banner_binary_body_without_dimensions
      Uploader::Account.update_profile_banner_binary(CONTENT, client: @client, boundary: BOUNDARY)

      assert_equal "/1.1/account/update_profile_banner.json", @request.uri.path
      assert_equal "multipart/form-data; boundary=#{BOUNDARY}", @request.headers["Content-Type"]
      assert_equal banner_body(CONTENT, BOUNDARY), @request.body.b
    end

    def test_update_profile_banner_binary_body_with_dimensions
      Uploader::Account.update_profile_banner_binary(CONTENT, client: @client, width: 1500, height: 500,
        offset_left: 10, offset_top: 20, boundary: BOUNDARY)

      expected = banner_body(CONTENT, BOUNDARY, width: 1500, height: 500, offset_left: 10, offset_top: 20)

      assert_equal expected, @request.body.b
    end

    def test_update_profile_banner_sends_file_content_and_dimensions
      Uploader::Account.update_profile_banner(PNG_FILE, client: @client, width: 1500, height: 500,
        offset_left: 10, offset_top: 20, boundary: BOUNDARY)

      expected = banner_body(File.binread(PNG_FILE), BOUNDARY, width: 1500, height: 500, offset_left: 10, offset_top: 20)

      assert_equal expected, @request.body.b
    end

    def test_update_profile_banner_binary_default_boundary
      Uploader::Account.update_profile_banner_binary(CONTENT, client: @client)

      assert_equal banner_body(CONTENT, request_boundary), @request.body.b
    end

    def test_update_profile_banner_default_boundary
      Uploader::Account.update_profile_banner(PNG_FILE, client: @client)

      assert_equal banner_body(File.binread(PNG_FILE), request_boundary), @request.body.b
    end

    private

    def request_boundary
      match = HEX_BOUNDARY.match(@request.headers["Content-Type"])

      refute_nil match, "Expected a random hex boundary in #{@request.headers["Content-Type"].inspect}"
      match[1]
    end

    def image_body(content, boundary)
      file_part("image", content, boundary)
    end

    def banner_body(content, boundary, **fields)
      fields.map { |name, value| field_part(name, value, boundary) }.join + file_part("banner", content, boundary)
    end

    def field_part(name, value, boundary)
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n"
    end

    def file_part(name, content, boundary)
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n" \
        "Content-Type: application/octet-stream\r\n\r\n#{content}\r\n--#{boundary}--\r\n".b
    end
  end
end
