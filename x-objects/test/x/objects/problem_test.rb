require_relative "../../test_helper"

module X
  class ProblemTest < Minitest::Test
    cover Problem
    cover ResourceNotFound

    NOT_FOUND = {"title" => "Not Found Error", "detail" => "Could not find tweet with pinned_tweet_id: [1].", "type" => "https://api.x.com/2/problems/resource-not-found",
                 "resource_type" => "tweet", "resource_id" => "1", "parameter" => "pinned_tweet_id", "value" => "1"}.freeze

    def test_attributes
      problem = Problem.new(NOT_FOUND)

      assert_equal ["Not Found Error", "Could not find tweet with pinned_tweet_id: [1].", "https://api.x.com/2/problems/resource-not-found"], [problem.title, problem.detail, problem.type]
      assert_equal %w[tweet 1 pinned_tweet_id 1], [problem.resource_type, problem.resource_id, problem.parameter, problem.value]
      assert_equal NOT_FOUND, problem.to_h
      assert_predicate problem, :frozen?
      assert_predicate problem.attrs, :frozen?
    end

    def test_not_found
      assert_predicate Problem.new(NOT_FOUND), :not_found?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/not-authorized-for-resource"}), :not_found?
      refute_predicate Problem.new({}), :not_found?
    end

    def test_inspect
      assert_equal "#<X::Problem Not Found Error: Could not find tweet with pinned_tweet_id: [1].>", Problem.new(NOT_FOUND).inspect
      assert_equal "#<X::Problem Not Found Error>", Problem.new({"title" => "Not Found Error"}).inspect
    end

    def test_attributes_are_deep_frozen
      problem = Problem.new({"title" => +"Not Found Error", "value" => [+"1"]})

      assert_predicate problem.attrs, :frozen?
      assert_predicate problem.title, :frozen?
      assert_predicate problem.value.first, :frozen?
    end

    def test_missing_attributes_are_nil
      problem = Problem.new({})

      assert_equal [nil] * 7, [problem.title, problem.detail, problem.type, problem.resource_type, problem.resource_id, problem.parameter, problem.value]
      refute_predicate problem, :not_found?
    end

    def test_all_from
      problems = Problem.all_from({"data" => {"id" => "1"}, "errors" => [NOT_FOUND, "not a problem"]})

      assert_equal [Problem], problems.map(&:class)
      assert_equal [NOT_FOUND], problems.map(&:to_h)
      assert_predicate problems, :frozen?
      assert_empty Problem.all_from({"data" => {"id" => "1"}})
      assert_empty Problem.all_from(nil)
    end

    def test_resource_not_found_explains_itself_with_the_first_problem
      error = ResourceNotFound.new("Could not find X::User nobody", problems: [Problem.new({"title" => "Not Found Error", "detail" => "Could not find user with username: [nobody]."}), Problem.new(NOT_FOUND)])

      assert_equal "Could not find X::User nobody: Could not find user with username: [nobody].", error.message
      assert_equal 2, error.problems.size
      assert_predicate error.problems, :frozen?
    end

    def test_resource_not_found_without_problems_or_detail
      assert_equal "Could not find X::User nobody", ResourceNotFound.new("Could not find X::User nobody").message
      assert_empty ResourceNotFound.new("Could not find X::User nobody").problems
      assert_equal "X::ResourceNotFound", ResourceNotFound.new.message
      assert_equal "Not Found Error", ResourceNotFound.new(problems: [Problem.new({"title" => "Not Found Error"})]).message
      assert_equal "Could not find X::User nobody: Not Found Error", ResourceNotFound.new("Could not find X::User nobody", problems: [Problem.new({"title" => "Not Found Error"})]).message
    end

    def test_resource_not_found_keeps_its_own_copy_of_the_problems
      problems = [Problem.new(NOT_FOUND)]
      error = ResourceNotFound.new("missing", problems:)
      problems.clear

      assert_equal 1, error.problems.size
    end
  end
end
