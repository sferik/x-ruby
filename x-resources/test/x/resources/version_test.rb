# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Resources
    class VersionTest < Minitest::Test
      cover "X::Resources.gem_version"

      def test_that_it_has_a_version_number
        refute_nil VERSION
      end

      def test_version_string
        assert_kind_of String, VERSION
      end

      def test_version_frozen
        assert_predicate VERSION, :frozen?
      end

      def test_gem_version
        assert_kind_of Gem::Version, Resources.gem_version
      end

      def test_gem_version_reads_version
        assert_equal VERSION, Resources.gem_version.to_s
      end

      def test_segments_array
        assert_kind_of Array, Resources.gem_version.segments
      end
    end
  end
end
