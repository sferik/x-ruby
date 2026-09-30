# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A lookup of several resources by their identifiers that finds none of them answers with a problem for each and no
  # data or meta, which builds an empty page of those problems, as a lookup that finds some builds a page of those
  class ResourceLookupOfSeveralTest < Minitest::Test
    cover Resource
    cover Page

    def not_found(parameter, value)
      {"title" => "Not Found Error", "detail" => "Could not find #{value}.", "type" => "https://api.x.com/2/problems/resource-not-found",
       "parameter" => parameter, "value" => value}
    end

    def test_a_lookup_of_several_that_finds_none_builds_an_empty_page_of_its_problems
      page = User.from_response({"errors" => [not_found("ids", "1"), not_found("ids", "2")]}, client: nil)

      assert_instance_of Page, page
      assert_empty page
      assert_equal %w[1 2], page.problems.map(&:value)
    end

    def test_a_lookup_of_several_by_any_parameter_that_names_them_builds_an_empty_page
      [%w[ids 1], %w[media_keys 3_1], %w[usernames sferik]].each do |parameter, value|
        assert_empty User.from_response({"errors" => [not_found(parameter, value)]}, client: nil)
      end
    end

    def test_a_lookup_of_several_that_reports_another_problem_beside_them_builds_an_empty_page
      assert_empty User.from_response({"errors" => [{"title" => "Something went wrong"}, not_found("ids", "1")]}, client: nil)
    end

    def test_a_lookup_of_one_that_finds_nothing_builds_nothing
      assert_nil User.from_response({"errors" => [not_found("id", "1")]}, client: nil)
      assert_nil User.from_response({"errors" => [{"title" => "Something went wrong"}]}, client: nil)
      assert_nil User.from_response({}, client: nil)
    end

    def test_a_lookup_of_several_that_finds_some_builds_a_page_of_them
      page = User.from_response({"data" => [{"id" => "1"}], "errors" => [not_found("ids", "2")]}, client: nil)

      assert_equal [1], page.map(&:id)
      assert_equal ["2"], page.problems.map(&:value)
    end

    def test_data_of_a_subclass_of_array_is_a_list
      assert_equal [1], User.from_response({"data" => Class.new(Array).new([{"id" => "1"}])}, client: nil).map(&:id)
    end

    def test_a_problem_of_a_lookup_of_several_beside_data_that_is_not_a_list_builds_nothing
      assert_nil User.from_response({"data" => "unreadable", "errors" => [not_found("ids", "1")]}, client: nil)
    end
  end
end
