# frozen_string_literal: true

require "stringio"
require "tmpdir"
require_relative "../../test_helper"
require "x/uploads/account"

module X
  # A profile image or banner larger than the endpoint takes is refused before any request
  class AccountSizeTest < Minitest::Test
    cover Uploads::Account
    cover Uploads.const_get(:Validator)

    PROFILE_IMAGE_URL = "https://api.x.com/1.1/account/update_profile_image.json"
    PROFILE_BANNER_URL = "https://api.x.com/1.1/account/update_profile_banner.json"
    PNG = File.binread("test/sample_files/sample.png").freeze
    MAX_IMAGE = 700 * 1024
    MAX_BANNER = 5 * 1024 * 1024

    def setup
      @client = Client.new(**test_oauth_credentials)
      stub_request(:post, PROFILE_IMAGE_URL).to_return(body: '{"id_str":"1"}', headers: {"Content-Type" => "application/json"})
      stub_request(:post, PROFILE_BANNER_URL)
    end

    def test_a_profile_image_of_as_much_as_the_api_takes_uploads
      Uploads::Account.update_profile_image(StringIO.new(png_of(MAX_IMAGE)), client: @client)

      assert_requested :post, PROFILE_IMAGE_URL
    end

    def test_a_larger_profile_image_is_refused_before_any_request
      error = assert_raises(InvalidMedia) { Uploads::Account.update_profile_image(StringIO.new(png_of(MAX_IMAGE + 1)), client: @client) }

      assert_equal "the media given is #{MAX_IMAGE + 1} bytes, more than the #{MAX_IMAGE} bytes the API takes of a profile image", error.message
      assert_not_requested :post, PROFILE_IMAGE_URL
    end

    def test_a_larger_profile_image_in_a_file_is_refused_before_any_request
      Dir.mktmpdir do |dir|
        path = File.join(dir, "avatar.png")
        File.binwrite(path, png_of(MAX_IMAGE + 1))
        error = assert_raises(InvalidMedia) { Uploads::Account.update_profile_image(path, client: @client) }

        assert_equal "#{path} is #{MAX_IMAGE + 1} bytes, more than the #{MAX_IMAGE} bytes the API takes of a profile image", error.message
      end
      assert_not_requested :post, PROFILE_IMAGE_URL
    end

    def test_a_banner_of_as_much_as_x_takes_uploads
      assert_nil Uploads::Account.update_profile_banner(StringIO.new(png_of(MAX_BANNER)), client: @client)
      assert_requested :post, PROFILE_BANNER_URL
    end

    def test_a_larger_banner_is_refused_before_any_request
      error = assert_raises(InvalidMedia) { Uploads::Account.update_profile_banner(StringIO.new(png_of(MAX_BANNER + 1)), client: @client) }

      assert_equal "the media given is #{MAX_BANNER + 1} bytes, more than the #{MAX_BANNER} bytes the API takes of a profile banner", error.message
      assert_not_requested :post, PROFILE_BANNER_URL
    end

    private

    def png_of(size) = PNG.b.ljust(size, "\x00")
  end
end
