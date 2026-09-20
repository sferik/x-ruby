# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class VersionTest < Minitest::Test
      def test_that_it_has_a_version_number
        refute_nil VERSION
      end

      def test_segments_array
        assert_kind_of Array, VERSION.segments
      end

      def test_to_s
        assert_kind_of String, VERSION.to_s
      end
    end
  end
end
