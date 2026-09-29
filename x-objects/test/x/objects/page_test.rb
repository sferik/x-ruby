# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PageTest < Minitest::Test
    cover Page

    def setup
      @users = [User.new({"id" => "1"}), User.new({"id" => "2"})]
      @page = Page.new(@users, {next_token: "abc", result_count: 2})
    end

    def test_items
      assert_equal @users, @page.items
      assert_predicate @page.items, :frozen?
    end

    def test_meta_is_deep_frozen_with_string_keys
      assert_equal({"next_token" => "abc", "result_count" => 2}, @page.meta)
      assert_predicate @page.meta, :frozen?
    end

    def test_items_that_are_not_resources_are_refused
      [nil, @users.first, [1], [@users.first, nil]].each do |items|
        error = assert_raises(ArgumentError) { Page.new(items, {}) }

        assert_equal "items must be an Array of resources, not #{items.inspect}", error.message
      end
    end

    def test_metadata_that_is_not_a_hash_is_refused
      error = assert_raises(ArgumentError) { Page.new(@users, nil) }

      assert_equal "meta must be a Hash, not nil", error.message
    end

    def test_what_converts_to_an_array_or_a_hash_is_taken_as_one
      page = Page.new(Struct.new(:to_ary).new(@users), Struct.new(:to_hash).new({"result_count" => 2}))

      assert_equal [@users, 2], [page.items, page.result_count]
    end

    def test_frozen
      assert_predicate @page, :frozen?
    end

    def test_each
      assert_equal [1, 2], @page.map(&:id)
      assert_equal @users, @page.each.to_a
      assert_equal @users, @page.each { |_user| nil }
    end

    def test_the_class_publishes_no_delegation_methods
      refute_respond_to Page, :def_delegator
      refute_respond_to Page, :delegate
    end

    def test_next_token
      assert_equal "abc", @page.next_token
      assert_nil Page.new([], {}).next_token
    end

    def test_result_count
      assert_equal 2, @page.result_count
      assert_nil Page.new([], {}).result_count
    end

    def test_problems_are_frozen
      problem = Problem.new({"title" => "Not Found Error"})
      page = Page.new([], {}, problems: [problem])

      assert_equal [problem], page.problems
      assert_predicate page.problems, :frozen?
      assert_empty @page.problems
    end
  end
end
