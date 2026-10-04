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
      assert_operator Uploads::Error, :<, Error
      assert_operator Streams::Error, :<, Error
      assert_operator UnsupportedFormat, :<, Error
    end

    def test_the_errors_of_a_stream_descend_from_the_error_of_x_streams
      assert_operator StreamError, :<, Streams::Error
      assert_operator RulesRejected, :<, Streams::Error
    end
  end
end
