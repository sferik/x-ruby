# frozen_string_literal: true

require "stringio"
require "tempfile"
require_relative "../../test_helper"
require "x/uploader/account"

module X
  # A profile image or banner is given as a path or as an IO, which is read from its start, and must begin with the
  # signature of a GIF, a JPEG, or a PNG, whatever its file is named
  class AccountIOTest < Minitest::Test
    cover Uploader::Account
    cover Uploader.const_get(:Validator)

    PROFILE_IMAGE_URL = "https://api.x.com/1.1/account/update_profile_image.json"
    PROFILE_BANNER_URL = "https://api.x.com/1.1/account/update_profile_banner.json"

    def setup
      @client = Client.new(**test_oauth_credentials)
      stub_request(:post, PROFILE_IMAGE_URL).to_return(body: '{"id_str":"1"}', headers: {"Content-Type" => "application/json"})
      stub_request(:post, PROFILE_BANNER_URL)
    end

    def test_a_profile_image_held_in_memory_uploads
      %w[png jpg gif].each do |extension|
        image = File.binread("test/sample_files/sample.#{extension}")
        io = StringIO.new(image)
        io.read

        assert_equal({"id_str" => "1"}, Uploader::Account.update_profile_image(io, client: @client))
        assert_requested(:post, PROFILE_IMAGE_URL) { |request| request.body.b.include?(image) }
      end
    end

    def test_a_profile_banner_open_on_a_file_uploads
      File.open("test/sample_files/sample.png", "rb") do |file|
        assert_nil Uploader::Account.update_profile_banner(file, client: @client, width: 1500)
      end
      assert_requested(:post, PROFILE_BANNER_URL) { |request| request.body.b.include?(File.binread("test/sample_files/sample.png")) }
    end

    def test_a_profile_image_read_from_stdin_redirected_from_a_file_uploads_as_the_image_its_signature_names
      File.open("test/sample_files/sample.png", "rb") do |file|
        stdin = IO.new(file.fileno, "rb", autoclose: false, path: "<STDIN>")

        assert_equal({"id_str" => "1"}, Uploader::Account.update_profile_image(stdin, client: @client))
      end
      assert_requested(:post, PROFILE_IMAGE_URL) { |request| request.body.b.include?(File.binread("test/sample_files/sample.png")) }
    end

    def test_media_held_in_memory_that_is_not_an_image_is_refused
      [File.binread("test/sample_files/sample.webp"), "not an image"].each do |content|
        error = assert_raises(InvalidMediaType) { Uploader::Account.update_profile_banner(StringIO.new(content), client: @client) }

        assert_equal "the media given is not a GIF, JPEG, or PNG image, which a profile banner must be", error.message
      end
      assert_not_requested(:post, PROFILE_BANNER_URL)
    end

    def test_an_empty_io_is_refused
      error = assert_raises(InvalidMedia) { Uploader::Account.update_profile_image(StringIO.new, client: @client) }

      assert_equal "the media given is empty: there is nothing to upload", error.message
    end

    def test_a_file_that_is_no_image_is_refused_by_its_signature
      File.open("test/sample_files/sample.mp4", "rb") do |file|
        error = assert_raises(InvalidMediaType) { Uploader::Account.update_profile_image(file, client: @client) }

        assert_equal "test/sample_files/sample.mp4 is not a GIF, JPEG, or PNG image, which a profile image must be", error.message
      end
      assert_not_requested(:post, PROFILE_IMAGE_URL)
    end

    def test_a_file_named_as_an_image_that_is_none_is_refused
      Tempfile.create(["avatar", ".png"]) do |file|
        file.binmode
        file.write(File.binread("test/sample_files/sample.mp4"))
        file.flush
        error = assert_raises(InvalidMediaType) { Uploader::Account.update_profile_image(file, client: @client) }

        assert_equal "#{file.path} is not a GIF, JPEG, or PNG image, which a profile image must be", error.message
      end
      assert_not_requested(:post, PROFILE_IMAGE_URL)
    end

    def test_an_image_in_a_file_named_as_none_is_taken_by_its_signature
      Tempfile.create("avatar") do |file|
        file.binmode
        file.write(File.binread("test/sample_files/sample.png"))
        file.flush

        assert_equal({"id_str" => "1"}, Uploader::Account.update_profile_image(file, client: @client))
        assert_nil Uploader::Account.update_profile_banner(file, client: @client)
      end
    end

    def test_the_client_methods_take_an_io
      @client.extend(Uploader::API)

      assert_equal({"id_str" => "1"}, @client.update_profile_image(StringIO.new(File.binread("test/sample_files/sample.png"))))
      assert_nil @client.update_profile_banner(StringIO.new(File.binread("test/sample_files/sample.jpg")), height: 500)
    end
  end
end
