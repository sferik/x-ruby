# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/utils"

module X
  # A response that holds problems in place of the data it describes media with raises X::MissingMediaData, which
  # holds them
  class UtilsProblemsTest < Minitest::Test
    cover Uploader.const_get(:Utils)

    def test_media_data_of_a_response_that_holds_problems_in_place_of_media_holds_them
      response = {"errors" => [{"title" => "Not Found Error", "detail" => "Could not find media"}]}
      error = assert_raises(MissingMediaData) { Uploader.const_get(:Utils).media_data(response, "of the upload") }

      assert_equal ["The response of the upload holds no media: Could not find media", ["Not Found Error"]], [error.message, error.problems.map(&:title)]
    end

    def test_described_of_a_response_that_holds_problems_in_place_of_metadata_holds_them
      response = {"errors" => [{"detail" => "Could not find media"}]}
      error = assert_raises(MissingMediaData) { Uploader.const_get(:Utils).described(response, 7) }

      assert_equal ["The response that adds the metadata holds none: Could not find media", 1], [error.message, error.problems.size]
    end
  end
end
