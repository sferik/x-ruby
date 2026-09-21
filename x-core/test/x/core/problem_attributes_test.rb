# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A problem is frozen, as every object the gems build from a response is, and so is what its attributes hold, so
  # that a problem read on one thread cannot be changed under another.
  class ProblemAttributesTest < Minitest::Test
    cover Problem

    def deep_frozen
      Problem.new({"title" => +"Not Found Error", "value" => [+"1", {"nested" => [+"2"]}], "count" => 1})
    end

    def test_attributes_are_deep_frozen
      problem = deep_frozen

      assert_equal [true] * 3, [problem.attrs, problem.title, problem.value].map(&:frozen?)
    end

    def test_what_the_attributes_hold_is_deep_frozen
      string, hash = deep_frozen.value
      array = hash["nested"]

      assert_equal [true] * 4, [string, hash, array, array.first].map(&:frozen?)
    end

    def test_a_value_that_cannot_be_frozen_is_kept_as_it_is
      assert_equal 1, deep_frozen.to_h["count"]
    end

    def test_deep_freezing_copies_the_strings_it_freezes
      title = +"Not Found Error"

      refute_predicate title, :frozen?, "the fixture must be unfrozen for the copy to be worth making"
      assert_predicate Problem.new({"title" => title}).title, :frozen?
      refute_predicate title, :frozen?
    end

    def test_attributes_are_read_by_string_however_they_were_given
      assert_equal "Not Found Error", Problem.new({title: "Not Found Error"}).title
    end
  end
end
