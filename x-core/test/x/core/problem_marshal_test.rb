# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Marshal writes a problem as plain data, led by the number of its format, and reads it back frozen
  class ProblemMarshalTest < Minitest::Test
    cover Problem

    ATTRS = {"title" => "Not Found Error", "resource_type" => "user", "resource_id" => "9", "errors" => [{"message" => "gone"}]}.freeze

    def setup
      @problem = Problem.new(ATTRS)
    end

    def test_marshal_dump_is_plain_data_led_by_its_format
      assert_equal [1, ATTRS], @problem.marshal_dump
    end

    def test_a_marshalled_problem_reads_back_as_it_was
      loaded = Marshal.load(Marshal.dump(@problem))

      assert_equal [ATTRS, "9", "Not Found Error"], [loaded.attrs, loaded.resource_id, loaded.title]
      assert_instance_of Problem, loaded
    end

    def test_a_marshalled_problem_reads_back_deep_frozen
      loaded = Marshal.load(Marshal.dump(@problem))

      assert_equal [true] * 4, [loaded, loaded.attrs, loaded.attrs["title"], loaded.attrs["errors"].first].map(&:frozen?)
    end

    def test_a_problem_of_another_format_is_refused
      error = assert_raises(UnsupportedMarshalFormat) { Problem.allocate.marshal_load(["1", ATTRS]) }

      assert_equal 'X::Problem reads format 1 of Marshal, not "1"', error.message
      assert_raises(UnsupportedMarshalFormat) { Problem.allocate.marshal_load(ATTRS) }
    end

    def test_the_format_is_named_privately
      assert_raises(NameError) { Problem::MARSHAL_FORMAT }
    end
  end
end
