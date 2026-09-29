# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Marshal writes a page as plain data, led by the number of its format, and reads it back frozen
  class PageMarshalTest < Minitest::Test
    cover Page

    def setup
      @user = User.new({"id" => "7", "username" => "sferik"}, client: FakeClient.new)
      @problem = Problem.new({"title" => "Not Found Error", "resource_id" => "9"})
      @page = Page.new([@user], {"result_count" => 1, "next_token" => "p2"}, problems: [@problem])
    end

    def test_marshal_dump_is_plain_data_led_by_its_format
      assert_equal [1, [@user], {"result_count" => 1, "next_token" => "p2"}, [{"title" => "Not Found Error", "resource_id" => "9"}]], @page.marshal_dump
    end

    def test_a_marshalled_page_reads_back_as_it_was
      loaded = Marshal.load(Marshal.dump(@page))

      assert_equal [[@user], "p2", 1, [@problem.attrs]], [loaded.items, loaded.next_token, loaded.result_count, loaded.problems.map(&:attrs)]
      assert_instance_of Problem, loaded.problems.first
      assert_nil loaded.first.client
    end

    def test_a_marshalled_page_reads_back_frozen
      loaded = Marshal.load(Marshal.dump(@page))

      assert_equal [true, true, true, true], [loaded, loaded.items, loaded.meta, loaded.problems].map(&:frozen?)
    end

    def test_a_page_of_another_format_is_refused
      error = assert_raises(ArgumentError) { Page.allocate.marshal_load(["2", [], {}, []]) }

      assert_equal "X::Page reads format 1 of Marshal, not \"2\"", error.message
    end
  end
end
