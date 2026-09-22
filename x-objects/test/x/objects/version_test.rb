# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class VersionTest < Minitest::Test
      cover "X::Objects.gem_version"

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
        assert_kind_of Gem::Version, Objects.gem_version
      end

      def test_gem_version_reads_version
        assert_equal VERSION, Objects.gem_version.to_s
      end

      def test_segments_array
        assert_kind_of Array, Objects.gem_version.segments
      end
    end
  end
end
