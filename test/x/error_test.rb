# frozen_string_literal: true

require_relative "../test_helper"

module X
  # x-core declares X::Error, which every error of every gem descends from, so the meta-gem, which loads them all,
  # checks that each does
  class MetaErrorTest < Minitest::Test
    def test_error_descends_from_standard_error
      assert_equal StandardError, Error.superclass
    end

    def test_every_error_of_every_gem_descends_from_error
      assert_operator HTTPError, :<, Error
      assert_operator MissingResource, :<, Error
      assert_operator Uploader::Error, :<, Error
      assert_operator Streaming::Error, :<, Error
      assert_operator UnsupportedMarshalFormat, :<, Error
    end

    def test_the_errors_of_a_stream_descend_from_the_error_of_x_streaming
      assert_operator StreamError, :<, Streaming::Error
      assert_operator RulesRejected, :<, Streaming::Error
    end
  end
end
