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
      assert_equal [1, [[User, {"id" => "7", "username" => "sferik"}, false, 0]], {"result_count" => 1, "next_token" => "p2"}, [@problem], [[{}, [], nil]]],
        @page.marshal_dump
    end

    SHARED = {"data" => [{"id" => "1", "author_id" => "9"}, {"id" => "2", "author_id" => "9"}, {"id" => "3", "author_id" => "8"}],
              "includes" => {"users" => [{"id" => "9", "username" => "sferik"}, {"id" => "8"}, {"id" => "7"}]}}.freeze

    def test_the_resources_of_one_response_share_what_they_refer_to_after_a_round_trip
      loaded = Marshal.load(Marshal.dump(Page.new(Post.collection_from_response(SHARED, client: nil, hydrated: true), {})))

      first, second, third = loaded.items

      assert_same first.author, second.author
      assert_equal ["sferik", [true] * 3], [second.author.username, [first, second, third].map(&:hydrated?)]
    end

    def test_the_resources_of_one_response_write_what_they_refer_to_once
      page = Page.new(Post.collection_from_response(SHARED, client: nil), {})

      assert_equal [[{"users" => [{"id" => "9", "username" => "sferik"}, {"id" => "8"}]}, [], nil]], page.marshal_dump.last
    end

    def test_the_resources_of_one_response_report_its_problems_and_resolve_as_hydrated_as_they_did
      body = {"data" => [{"id" => "1", "author_id" => "9", "attachments" => {"poll_ids" => ["5"]}}], "includes" => {"polls" => [{"id" => "5"}]},
              "errors" => [{"title" => "Not Found Error", "resource_id" => "9"}]}
      post = Marshal.load(Marshal.dump(Page.new(Post.__send__(:collection_built_from, body, client: nil, hydrated: false, query: Objects::Utils.query(Post.default_params)), {}))).first

      assert_equal [["9"], true], [post.problems.map(&:resource_id), post.polls.first.hydrated?]
    end

    def test_the_resources_of_several_responses_keep_what_each_response_held
      page = Page.new([by_author("sferik"), by_author("gem")].then { |first, second| [first, second, first] }, {})
      loaded = Marshal.load(Marshal.dump(page))

      assert_equal [0, 1, 0], page.marshal_dump[1].map(&:last)
      assert_equal %w[sferik gem sferik], loaded.map { |post| post.author.username }
    end

    def test_the_resources_of_several_responses_share_what_one_response_held
      first, second, third = Marshal.load(Marshal.dump(Page.new([by_author("sferik"), by_author("gem")].then { |one, other| [one, other, one] }, {}))).map(&:author)

      refute_same first, second
      assert_same first, third
    end

    def test_a_marshalled_page_reads_back_as_it_was
      loaded = Marshal.load(Marshal.dump(@page))

      assert_equal [[@user], "p2", 1, [@problem.attrs]], [loaded.items, loaded.next_token, loaded.result_count, loaded.problems.map(&:attrs)]
      assert_instance_of Problem, loaded.problems.first
      assert_nil loaded.first.client
    end

    def test_a_marshalled_page_reads_back_its_resources_as_they_were
      resource = Marshal.load(Marshal.dump(@page)).first

      assert_equal [User, {"id" => "7", "username" => "sferik"}], [resource.class, resource.attrs]
    end

    def test_a_marshalled_page_reads_back_frozen
      loaded = Marshal.load(Marshal.dump(@page))

      assert_equal [true, true, true, true], [loaded, loaded.items, loaded.meta, loaded.problems].map(&:frozen?)
    end

    def test_a_page_of_another_format_is_refused
      error = assert_raises(UnsupportedMarshalFormat) { Page.allocate.marshal_load(["2", [], {}, []]) }

      assert_equal "X::Page reads format 1 of Marshal, not \"2\"", error.message
    end

    private

    # A post by the author a response of its own included, by username
    def by_author(username) = Post.from_response({"data" => {"id" => "1", "author_id" => "9"}, "includes" => {"users" => [{"id" => "9", "username" => username}]}}, client: nil)
  end
end
