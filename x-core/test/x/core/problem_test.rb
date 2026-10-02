# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ProblemTest < Minitest::Test
    cover Problem

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

    def test_problems_of_the_same_attributes_are_equal
      problem = Problem.new(NOT_FOUND)
      same = Problem.new(NOT_FOUND.transform_keys(&:to_sym))

      assert_equal problem, same
      assert problem.eql?(same)
      assert_equal 1, {problem => 1}.fetch(same)
      assert_equal [problem], [problem, same, Marshal.load(Marshal.dump(same))].uniq
    end

    def test_problems_of_other_attributes_are_not_equal
      problem = Problem.new(NOT_FOUND)
      other = Problem.new(NOT_FOUND.merge("value" => "2"))

      refute_equal problem, other
      refute_equal problem.hash, other.hash
      refute_equal problem, NOT_FOUND
    end

    def test_problems_of_another_class_are_not_equal
      problem = Problem.new(NOT_FOUND)
      subclassed = Class.new(Problem).new(NOT_FOUND)

      refute_equal problem, subclassed
      refute_equal problem.hash, subclassed.hash
    end

    def identifiers(attrs) = Problem.new(attrs).then { |problem| [problem.resource_id, problem.value] }

    def test_an_identifier_is_the_string_the_api_gave_whatever_the_kind_of_resource
      %w[user tweet post list dm_event community poll space media].each do |resource_type|
        assert_equal %w[0123 0123], identifiers({"resource_type" => resource_type, "resource_id" => "0123", "parameter" => "ids", "value" => "0123"})
      end
      assert_equal %w[sferik sferik], identifiers({"resource_type" => "user", "resource_id" => "sferik", "parameter" => "usernames", "value" => "sferik"})
      assert_equal %w[1234 1234], identifiers({"resource_id" => "1234", "value" => "1234"})
    end

    # A resource, as the object layer builds one, with an identifier
    Identified = Struct.new(:id)

    def test_a_problem_is_about_the_resource_its_resource_id_names
      problem = Problem.new(NOT_FOUND)

      assert_equal [true, true, true], [1, "1", Identified.new(1)].map { |resource| problem.about?(resource) }
      assert_equal [false, false, false], [2, "01", Identified.new("2")].map { |resource| problem.about?(resource) }
      assert Problem.new({"resource_id" => "sferik"}).about?("sferik")
    end

    def test_a_problem_that_names_no_resource_is_about_none
      problem = Problem.new({"title" => "Not Found Error"})

      assert_equal [false, false], ["", Identified.new(nil)].map { |resource| problem.about?(resource) }
    end

    def test_a_value_that_is_not_a_string_is_as_the_api_gave_it
      assert_equal [nil, ["1"]], identifiers({"resource_type" => "user", "value" => ["1"]})
      assert_equal [nil, 1], identifiers({"resource_type" => "user", "value" => 1})
    end

    def test_the_message_of_an_error_the_api_named
      assert_equal "Could not authenticate you", Problem.new({"message" => "Could not authenticate you", "code" => 32}).message
      assert_nil Problem.new(NOT_FOUND).message
    end

    def test_inspect
      assert_equal "#<X::Problem Not Found Error: Could not find tweet with pinned_tweet_id: [1].>", Problem.new(NOT_FOUND).inspect
      assert_equal "#<X::Problem Not Found Error>", Problem.new({"title" => "Not Found Error"}).inspect
    end

    def test_inspect_reads_the_message_of_a_problem_that_has_no_detail
      assert_equal "#<X::Problem Could not authenticate you>", Problem.new({"message" => "Could not authenticate you", "code" => 32}).inspect
      assert_equal "#<X::Problem Unauthorized: Could not authenticate you>", Problem.new({"title" => "Unauthorized", "message" => "Could not authenticate you"}).inspect
    end

    def test_inspect_reads_the_detail_of_a_problem_that_has_both
      assert_equal "#<X::Problem Not Found Error: Could not find user>", Problem.new({"title" => "Not Found Error", "detail" => "Could not find user", "message" => "Could not find user with id: [1]."}).inspect
    end

    def test_missing_attributes_are_nil
      problem = Problem.new({})

      assert_equal [nil] * 8, [problem.title, problem.detail, problem.type, problem.resource_type, problem.resource_id, problem.parameter, problem.value, problem.message]
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

    def test_serialization
      problem = Problem.new({"title" => "Not Found Error"})

      assert_equal({"title" => "Not Found Error"}, problem.as_json)
      assert_same problem.attrs, problem.as_json
      assert_equal '{"title":"Not Found Error"}', problem.to_json
      assert_equal '{"problem":{"title":"Not Found Error"}}', {problem:}.to_json
    end

    def test_to_json_is_generated_with_the_state_it_is_given
      problem = Problem.new({"title" => "Not Found Error"})

      assert_equal "{\n  \"title\": \"Not Found Error\"\n}", problem.to_json(JSON::State.new(indent: "  ", object_nl: "\n", space: " "))
    end
  end
end
