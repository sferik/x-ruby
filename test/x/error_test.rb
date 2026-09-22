# frozen_string_literal: true

require_relative "../test_helper"

module X
  # x-core and x-objects each define X::Error, since x-objects does not depend on x-core, so the meta-gem, which loads
  # both, checks that the two definitions agree
  class MetaErrorTest < Minitest::Test
    def test_error_descends_from_standard_error
      assert_equal StandardError, Error.superclass
    end

    def test_every_error_of_every_gem_descends_from_error
      assert_operator HTTPError, :<, Error
      assert_operator MissingResource, :<, Error
      assert_operator Uploader::Error, :<, Error
    end
  end
end
