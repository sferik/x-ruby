# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UtilsMediaKeyTest < Minitest::Test
    cover Uploader.const_get(:Utils)

    def test_media_id_of_a_media_key
      assert_equal "1880028106020515840", Uploader.const_get(:Utils).media_id("3_1880028106020515840")
    end

    def test_media_id_of_a_string_that_is_neither_a_media_key_nor_an_identifier
      %w[3_ 3_7x 3-7].each do |text|
        error = assert_raises(ArgumentError, text) { Uploader.const_get(:Utils).media_id(text) }

        assert_equal "The media identifier #{text.inspect} is none the API takes, which is 1 to 19 digits", error.message
      end
    end
  end
end
