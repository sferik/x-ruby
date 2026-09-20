require_relative "../../test_helper"

module X
  class ProblemTest < Minitest::Test
    cover Problem
    cover MissingResource

    NOT_FOUND = {"title" => "Not Found Error", "detail" => "Could not find tweet with pinned_tweet_id: [1].", "type" => "https://api.x.com/2/problems/resource-not-found",
                 "resource_type" => "tweet", "resource_id" => "1", "parameter" => "pinned_tweet_id", "value" => "1"}.freeze

    def test_attributes
      problem = Problem.new(NOT_FOUND)

      assert_equal ["Not Found Error", "Could not find tweet with pinned_tweet_id: [1].", "https://api.x.com/2/problems/resource-not-found"], [problem.title, problem.detail, problem.type]
      assert_equal ["tweet", 1, "pinned_tweet_id", 1], [problem.resource_type, problem.resource_id, problem.parameter, problem.value]
      assert_equal NOT_FOUND, problem.to_h
      assert_predicate problem, :frozen?
      assert_predicate problem.attrs, :frozen?
    end

    def identifiers(attrs) = Problem.new(attrs).then { |problem| [problem.resource_id, problem.value] }

    def test_the_identifier_of_a_resource_with_numeric_identifiers_is_an_integer
      %w[user tweet post list dm_event community poll].each do |resource_type|
        assert_equal [7505382, 7505382], identifiers({"resource_type" => resource_type, "resource_id" => "7505382", "parameter" => "ids", "value" => "7505382"})
      end
      assert_equal [123, 123], identifiers({"resource_type" => "user", "resource_id" => "0123", "value" => "0123"})
      assert_equal Post.from_id(1).id, Problem.new(NOT_FOUND).resource_id
    end

    def test_a_username_remains_a_string_even_when_it_is_all_digits
      %w[username usernames entities.mentions.username].each do |parameter|
        assert_equal %w[1234 1234], identifiers({"resource_type" => "user", "resource_id" => "1234", "parameter" => parameter, "value" => "1234"})
      end
      assert_equal [1234, 1234], identifiers({"resource_type" => "user", "resource_id" => "1234", "parameter" => "usernames.id", "value" => "1234"})
    end

    def test_an_identifier_that_is_not_a_number_remains_a_string
      assert_equal %w[1234 1234], identifiers({"resource_type" => "space", "resource_id" => "1234", "parameter" => "ids", "value" => "1234"})
      assert_equal %w[1234 1234], identifiers({"resource_id" => "1234", "value" => "1234"})
      assert_equal %w[sferik sferik], identifiers({"resource_type" => "user", "resource_id" => "sferik", "value" => "sferik"})
      assert_equal ["1\nx", "x\n1"], identifiers({"resource_type" => "user", "resource_id" => "1\nx", "value" => "x\n1"})
    end

    def test_a_value_that_is_not_a_string_is_as_the_api_gave_it
      assert_equal [nil, ["1"]], identifiers({"resource_type" => "user", "value" => ["1"]})
      assert_equal [nil, 1], identifiers({"resource_type" => "user", "value" => 1})
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
      error = MissingResource.new("Could not find X::User nobody", problems: [Problem.new({"title" => "Not Found Error", "detail" => "Could not find user with username: [nobody]."}), Problem.new(NOT_FOUND)])

      assert_equal "Could not find X::User nobody: Could not find user with username: [nobody].", error.message
      assert_equal 2, error.problems.size
      assert_predicate error.problems, :frozen?
    end

    def test_resource_not_found_without_problems_or_detail
      assert_equal "Could not find X::User nobody", MissingResource.new("Could not find X::User nobody").message
      assert_empty MissingResource.new("Could not find X::User nobody").problems
      assert_equal "X::MissingResource", MissingResource.new.message
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
