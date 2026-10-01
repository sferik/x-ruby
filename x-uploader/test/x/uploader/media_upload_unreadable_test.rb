# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "tempfile"
require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  class MediaUploadUnreadableTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Validator)
    cover Uploader.const_get(:Source)

    BASE_URL = "https://api.x.com/2/media/upload"

    def setup
      @client = Client.new
    end

    def assert_refused_before_any_request(description, &)
      error = assert_raises(InvalidMedia, &)

      assert_equal "#{description} cannot be read: it is not a file, or not one open for reading", error.message
      assert_not_requested :post, "#{BASE_URL}/initialize"
      assert_not_requested :post, BASE_URL
    end

    def test_a_directory_is_refused_before_any_request
      Dir.mktmpdir(["media", ".mp4"]) do |directory|
        assert_refused_before_any_request(directory) { Uploader::MediaUpload.upload(directory, client: @client) }
      end
    end

    def test_a_file_the_process_cannot_read_is_refused_before_any_request
      File.stub(:readable?, false) do
        assert_refused_before_any_request("test/sample_files/sample.mp4") do
          Uploader::MediaUpload.upload("test/sample_files/sample.mp4", client: @client)
        end
      end
    end

    def test_a_closed_string_io_is_refused_before_any_request
      io = StringIO.new(File.binread("test/sample_files/sample.png")).tap(&:close)
      error = assert_raises(InvalidMedia) { Uploader::MediaUpload.upload(io, client: @client) }

      assert_equal "the media given cannot be read: closed stream", error.message
      assert_not_requested :post, BASE_URL
    end

    def test_a_string_io_open_to_write_alone_is_refused_and_given_back_at_its_position
      io = StringIO.new(+"0123456789", "w")
      io.seek(4)
      error = assert_raises(InvalidMedia) { Uploader::MediaUpload.upload(io, client: @client) }

      assert_equal "the media given cannot be read: not opened for reading", error.message
      assert_equal 4, io.pos
      assert_not_requested :post, BASE_URL
    end

    def test_an_io_open_to_write_alone_is_refused_before_any_request
      Tempfile.create(["media", ".mp4"]) do |file|
        file.binmode
        file.write(File.binread("test/sample_files/sample.mp4"))
        file.flush

        File.open(file.path, "a") do |io|
          assert_refused_before_any_request(file.path) { Uploader::MediaUpload.upload(io, client: @client) }
        end
      end
    end

    def test_an_io_open_on_a_directory_is_refused_before_any_request
      skip "a directory cannot be opened as a file on Windows" if Gem.win_platform?

      Dir.mktmpdir do |directory|
        File.open(directory) do |io|
          assert_refused_before_any_request("the media given") do
            Uploader::MediaUpload.upload(io, client: @client, media_category: "tweet_video", media_type: "video/mp4")
          end
        end
      end
    end

    def test_an_io_open_to_read_and_write_is_read_and_left_where_it_was
      Tempfile.create(["media", ".png"]) do |file|
        file.binmode
        file.write(File.binread("test/sample_files/sample.png"))
        file.seek(1)
        stub_request(:post, BASE_URL).to_return(headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json)

        assert_equal [TEST_MEDIA_ID, 1], [Uploader::MediaUpload.upload(file, client: @client)["id"], file.pos]
      end
    end
  end
end
