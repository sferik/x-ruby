# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Uploaded media holds the identifier a post attaches it by, as every upload and status response does, so media built
  # without one is refused when it is built, rather than when its identifier is read
  class UploadedMediaIdentifierTest < Minitest::Test
    cover UploadedMedia

    def test_media_that_holds_no_identifier_is_refused
      [{}, {"media_key" => "3_7"}, {id: "7"}, {"id" => nil}, {"id" => ""}, {"id" => "7x"}, {"id" => -7}, {"id" => 7.0},
        {"id" => "1" * 20}, {"id" => 10**19}].each do |attrs|
        error = assert_raises(ArgumentError, attrs.inspect) { UploadedMedia.new(attrs) }

        assert_equal "attrs must hold the \"id\" of the media, an Integer or a String of 1 to 19 digits, as an upload returns it, not #{attrs.fetch("id", nil).inspect}", error.message
      end
    end

    def test_media_that_holds_an_identifier_as_an_integer_or_a_string_of_digits_is_built
      assert_equal [7, 7, 10], [UploadedMedia.new({"id" => 7}).id, UploadedMedia.new({"id" => "7"}).id, UploadedMedia.new({"id" => "010"}).id]
    end

    def test_media_that_holds_an_identifier_of_nineteen_digits_is_built
      assert_equal [1_111_111_111_111_111_111, 10**19 - 1], [UploadedMedia.new({"id" => "1" * 19}).id, UploadedMedia.new({"id" => 10**19 - 1}).id]
    end
  end
end
