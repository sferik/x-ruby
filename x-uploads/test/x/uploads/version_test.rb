# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class VersionTest < Minitest::Test
    cover "X::Uploads.gem_version"

    def test_that_it_has_a_version_number
      refute_nil Uploads::VERSION
    end

    def test_version_string
      assert_kind_of String, Uploads::VERSION
    end

    def test_version_frozen
      assert_predicate Uploads::VERSION, :frozen?
    end

    def test_gem_version
      assert_kind_of Gem::Version, Uploads.gem_version
    end

    def test_gem_version_reads_version
      assert_equal Uploads::VERSION, Uploads.gem_version.to_s
    end

    def test_segments_array
      assert_kind_of Array, Uploads.gem_version.segments
    end

    def test_major_version_integer
      assert_kind_of Integer, Uploads.gem_version.segments[0]
    end

    def test_minor_version_integer
      assert_kind_of Integer, Uploads.gem_version.segments[1]
    end

    def test_patch_version_integer
      assert_kind_of Integer, Uploads.gem_version.segments[2]
    end
  end
end
