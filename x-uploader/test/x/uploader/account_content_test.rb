# frozen_string_literal: true

require "tempfile"
require "stringio"
require_relative "../../test_helper"
require "x/uploader/account"

module X
  class AccountContentTest < Minitest::Test
    cover Uploader::Account
    cover Uploader.const_get(:Validator)

    def setup
      @client = Client.new(**test_oauth_credentials)
    end

    def each_update(content)
      yield(-> { Uploader::Account.update_profile_image(StringIO.new(content), client: @client) })
      yield(-> { Uploader::Account.update_profile_banner(StringIO.new(content), client: @client, width: 1500) })
    end

    def test_empty_content_is_refused_before_a_request
      each_update("") do |update|
        assert_equal "the media given is empty: there is nothing to upload", assert_raises(InvalidMedia) { update.call }.message
      end
      assert_not_requested :post, /api\.x\.com/
    end

    def test_content_that_is_not_a_gif_a_jpeg_or_a_png_is_refused_before_a_request
      each_update("RIFF\x00\x00\x00\x00WEBPVP8 ".b) do |update|
        assert_match(/\Athe media given is not a GIF, JPEG, or PNG image, which a profile (image|banner) must be\z/,
          assert_raises(InvalidMediaType) { update.call }.message)
      end
      assert_not_requested :post, /api\.x\.com/
    end

    def test_an_empty_file_named_as_an_image_is_refused_before_a_request
      Tempfile.create(["empty", ".png"]) do |file|
        error = assert_raises(InvalidMedia) { Uploader::Account.update_profile_image(file.path, client: @client) }

        assert_equal "#{file.path} is empty: there is nothing to upload", error.message
      end
      assert_not_requested :post, /api\.x\.com/
    end

    def test_a_gif_a_jpeg_and_a_png_are_sent
      stub_request(:post, %r{\Ahttps://api\.x\.com/1\.1/account/})
      ["GIF87a".b, "\xFF\xD8\xFF\xE0".b, "\x89PNG\r\n\x1A\n".b].each do |content|
        each_update(content, &:call)
      end

      assert_requested :post, "https://api.x.com/1.1/account/update_profile_image.json", times: 3
      assert_requested :post, "https://api.x.com/1.1/account/update_profile_banner.json", times: 3
    end
  end
end
