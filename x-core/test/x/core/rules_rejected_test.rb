# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class RulesRejectedTest < Minitest::Test
    cover RulesRejected

    def test_rules_rejected_is_an_error
      assert_operator RulesRejected, :<, Error
    end

    def test_rules_rejected_freezes_a_copy_of_the_problems_it_is_given
      problems = []
      error = RulesRejected.new(problems, result: 0)

      assert_equal [true, [], false], [error.problems.frozen?, error.problems, problems.frozen?]
    end

    def test_rules_rejected_holds_what_the_method_would_have_returned
      assert_equal 2, RulesRejected.new([], result: 2).result
    end

    def test_the_message_names_each_problem_by_its_title_and_detail_or_message
      problems = [Problem.new({"title" => "DuplicateRule", "detail" => "Duplicate rule"}), Problem.new({"message" => "Rule does not exist"})]

      assert_equal "DuplicateRule: Duplicate rule, Rule does not exist", RulesRejected.new(problems, result: []).message
    end
  end
end
