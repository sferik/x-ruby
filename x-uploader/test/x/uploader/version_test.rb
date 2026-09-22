# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class VersionTest < Minitest::Test
    cover "X::Uploader.gem_version"

    def test_that_it_has_a_version_number
      refute_nil Uploader::VERSION
    end

    def test_version_string
      assert_kind_of String, Uploader::VERSION
    end

    def test_version_frozen
      assert_predicate Uploader::VERSION, :frozen?
    end

    def test_gem_version
      assert_kind_of Gem::Version, Uploader.gem_version
    end

    def test_gem_version_reads_version
      assert_equal Uploader::VERSION, Uploader.gem_version.to_s
    end

    def test_segments_array
      assert_kind_of Array, Uploader.gem_version.segments
    end

    def test_major_version_integer
      assert_kind_of Integer, Uploader.gem_version.segments[0]
    end

    def test_minor_version_integer
      assert_kind_of Integer, Uploader.gem_version.segments[1]
    end

    def test_patch_version_integer
      assert_kind_of Integer, Uploader.gem_version.segments[2]
    end
  end
end
