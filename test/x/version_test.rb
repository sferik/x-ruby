require_relative "../test_helper"
require "x/uploader/version"

module X
  class MetaVersionTest < Minitest::Test
    def test_that_it_has_a_version_number
      refute_nil VERSION
    end

    def test_segments_array
      assert_kind_of Array, VERSION.segments
    end

    def test_to_s
      assert_kind_of String, VERSION.to_s
    end

    def test_lockstep_versions
      assert_equal VERSION, Core::VERSION
      assert_equal VERSION, Uploader::VERSION
      assert_equal VERSION, Objects::VERSION
    end
  end
end
