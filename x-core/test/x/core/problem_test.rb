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

    def identifiers(attrs) = Problem.new(attrs).then { |problem| [problem.resource_id, problem.value] }

    def test_an_identifier_is_the_string_the_api_gave_whatever_the_kind_of_resource
      %w[user tweet post list dm_event community poll space media].each do |resource_type|
        assert_equal %w[0123 0123], identifiers({"resource_type" => resource_type, "resource_id" => "0123", "parameter" => "ids", "value" => "0123"})
      end
      assert_equal %w[sferik sferik], identifiers({"resource_type" => "user", "resource_id" => "sferik", "parameter" => "usernames", "value" => "sferik"})
      assert_equal %w[1234 1234], identifiers({"resource_id" => "1234", "value" => "1234"})
    end

    def test_a_value_that_is_not_a_string_is_as_the_api_gave_it
      assert_equal [nil, ["1"]], identifiers({"resource_type" => "user", "value" => ["1"]})
      assert_equal [nil, 1], identifiers({"resource_type" => "user", "value" => 1})
    end

    def test_the_message_of_an_error_the_api_named
      assert_equal "Could not authenticate you", Problem.new({"message" => "Could not authenticate you", "code" => 32}).message
      assert_nil Problem.new(NOT_FOUND).message
    end

    def test_not_found
      assert_predicate Problem.new(NOT_FOUND), :not_found?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/not-authorized-for-resource"}), :not_found?
      refute_predicate Problem.new({}), :not_found?
    end

    def test_disconnect
      assert_predicate Problem.new({"type" => "https://api.twitter.com/2/problems/operational-disconnect"}), :disconnect?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/operational-disconnect-soon"}), :disconnect?
      refute_predicate Problem.new({"type" => "https://api.x.com/2/problems/streaming-connection"}), :disconnect?
      refute_predicate Problem.new({"title" => "operational-disconnect"}), :disconnect?
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

    def test_from
      problem = Problem.from(NOT_FOUND)

      assert_instance_of Problem, problem
      assert_equal NOT_FOUND, problem.to_h
      assert_nil Problem.from(nil)
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
