# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class UtilsQueryTest < Minitest::Test
      cover Utils

      def test_query_sends_a_time_in_iso_8601_in_utc
        time = Time.new(2026, 9, 16, 11, 30, 0, "-07:00")

        assert_equal({"start_time" => "2026-09-16T18:30:00Z"}, Utils.query({start_time: time}))
        assert_equal "-07:00", time.strftime("%:z")
      end
    end
  end
end
