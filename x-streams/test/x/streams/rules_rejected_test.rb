# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RulesRejectedTest < Minitest::Test
    cover RulesRejected
    cover "X::Streams::Error#describe"

    def test_rules_rejected_is_an_error
      assert_operator RulesRejected, :<, Error
    end

    def test_rules_rejected_freezes_a_copy_of_the_problems_it_is_given
      problems = []
      error = RulesRejected.new(problems:, deleted_count: 0)

      assert_equal [true, [], false], [error.problems.frozen?, error.problems, problems.frozen?]
    end

    def test_rules_rejected_holds_what_the_method_would_have_returned
      rules = [StreamRule.new(id: 1, value: "ruby")]
      added = RulesRejected.new(added: rules)

      assert_equal [rules, true, false, nil], [added.added, added.added.frozen?, rules.frozen?, added.deleted_count]
      assert_equal [nil, 2], RulesRejected.new(deleted_count: 2).then { |error| [error.added, error.deleted_count] }
    end

    def test_the_message_names_each_problem_by_its_title_and_detail_or_message
      problems = [Problem.new({"title" => "DuplicateRule", "detail" => "Duplicate rule"}), Problem.new({"message" => "Rule does not exist"})]

      assert_equal "DuplicateRule: Duplicate rule, Rule does not exist", RulesRejected.new(problems:, added: []).message
    end

    def test_rules_rejected_is_raised_with_a_message_alone_as_any_exception_is
      problems = [Problem.new({"title" => "DuplicateRule"})]
      error = assert_raises(RulesRejected) { raise RulesRejected, "The rules were not added" }

      assert_equal ["The rules were not added", [], nil, nil], [error.message, error.problems, error.added, error.deleted_count]
      assert_equal "The rules were not added", RulesRejected.new("The rules were not added", problems:).message
    end

    def test_rules_rejected_is_raised_with_nothing_as_any_exception_is
      error = assert_raises(RulesRejected) { raise RulesRejected }

      assert_equal ["X::RulesRejected", [], nil, nil], [error.message, error.problems, error.added, error.deleted_count]
    end
  end
end
