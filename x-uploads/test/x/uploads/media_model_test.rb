# frozen_string_literal: true

require_relative "../../test_helper"
require "tempfile"
require "x/uploads/media_upload"

module X
  # A 3D model, which the initialization of an upload takes the media type of, but no media category takes, is
  # refused before a request, rather than sent as an image X refuses once it is uploaded
  class MediaModelTest < Minitest::Test
    cover Uploads::MediaUpload
    cover Uploads.const_get(:Signature)

    GLTF = "glTF\x02\x00\x00\x00".b.freeze

    def setup
      @client = Client.new
    end

    def test_a_glb_or_usdz_file_uploads_nothing
      {".glb" => "glTF", ".usdz" => "USDZ"}.each do |extension, format|
        in_file(extension, GLTF) do |path|
          error = assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload(path, client: @client) }

          assert_equal "no media category the API documents takes a #{format} 3D model, such as #{path}", error.message
        end
      end

      assert_not_requested :any, /x\.com/
    end

    def test_a_glb_file_is_refused_whatever_it_begins_with
      in_file(".glb", "\x89PNG\r\n\x1A\n".b) { |path| assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload(path, client: @client) } }
      assert_not_requested :any, /x\.com/
    end

    def test_a_nameless_gltf_model_is_typed_by_no_signature
      error = assert_raises(InvalidMediaType) { Uploads::MediaUpload.upload(StringIO.new(GLTF), client: @client) }

      assert_equal "unable to determine the media type of the media given: pass media_category", error.message
      assert_not_requested :any, /x\.com/
    end

    private

    # Write bytes to a file of an extension, and yield its path
    def in_file(extension, bytes)
      Tempfile.create(["model", extension]) do |file|
        file.binmode
        file.write(bytes.ljust(64, "\x00"))
        file.flush
        yield file.path
      end
    end
  end
end
