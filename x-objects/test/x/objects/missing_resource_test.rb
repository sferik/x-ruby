# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class MissingResourceTest < Minitest::Test
      cover MissingResource

      NOT_FOUND = {"title" => "Not Found Error", "detail" => "Could not find tweet with pinned_tweet_id: [1].", "type" => "https://api.x.com/2/problems/resource-not-found",
                   "resource_type" => "tweet", "resource_id" => "1", "parameter" => "pinned_tweet_id", "value" => "1"}.freeze

      def test_the_problems_of_a_lookup_are_the_problems_x_core_reads
        assert_equal Post.from_id(1).id, Problem.new(NOT_FOUND).resource_id
      end

      def test_resource_not_found_explains_itself_with_the_first_problem
        error = MissingResource.new("Could not find X::User nobody", problems: [Problem.new({"title" => "Not Found Error", "detail" => "Could not find user with username: [nobody]."}), Problem.new(NOT_FOUND)])

        assert_equal "Could not find X::User nobody: Could not find user with username: [nobody].", error.message
        assert_equal 2, error.problems.size
        assert_predicate error.problems, :frozen?
      end

      def test_resource_not_found_without_problems_or_detail
        assert_equal "Could not find X::User nobody", MissingResource.new("Could not find X::User nobody").message
        assert_empty MissingResource.new("Could not find X::User nobody").problems
        assert_equal "X::Objects::MissingResource", MissingResource.new.message
        assert_equal "Not Found Error", MissingResource.new(problems: [Problem.new({"title" => "Not Found Error"})]).message
        assert_equal "Could not find X::User nobody: Not Found Error", MissingResource.new("Could not find X::User nobody", problems: [Problem.new({"title" => "Not Found Error"})]).message
      end

      def test_resource_not_found_keeps_its_own_copy_of_the_problems
        problems = [Problem.new(NOT_FOUND)]
        error = MissingResource.new("missing", problems:)
        problems.clear

        assert_equal 1, error.problems.size
      end
    end
  end
end
