# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    # What Marshal writes of the response of a resource is the included objects it refers to, and those they refer to in
    # turn, with the problems about them, and none of the rest of the response
    class IncludesStateTest < Minitest::Test
      cover Includes

      QUERY = {"tweet.fields" => "text"}.freeze

      def setup
        @data = {"users" => [{"id" => "9", "pinned_tweet_id" => "3"}, {"id" => "10"}, {"id" => "11"}],
                 "tweets" => [{"id" => "3", "author_id" => "11"}, {"id" => "2", "author_id" => "10"}, {"id" => "4"}],
                 "media" => [{"media_key" => "3_1"}, {"media_key" => "3_2"}], "polls" => [{"id" => "5"}], "places" => [{"id" => "p1"}],
                 "topics" => [{"id" => "848920371311001600"}]}
        @includes = Includes.new(@data, problems: [problem("9"), problem("12"), problem(nil)], query: QUERY)
      end

      def test_a_resource_keeps_the_included_objects_it_refers_to_alone
        data, = @includes.state_of([post({"author_id" => "10", "attachments" => {"media_keys" => ["3_2"], "poll_ids" => ["5"]}})])

        assert_equal({"users" => [{"id" => "10"}], "media" => [{"media_key" => "3_2"}], "polls" => [{"id" => "5"}]}, data)
      end

      def test_a_resource_keeps_what_the_objects_it_refers_to_refer_to_in_turn
        data, = @includes.state_of([post({"author_id" => "9", "referenced_tweets" => [{"type" => "quoted", "id" => "2"}]})])

        assert_equal({"users" => [{"id" => "9", "pinned_tweet_id" => "3"}, {"id" => "10"}, {"id" => "11"}],
                      "tweets" => [{"id" => "3", "author_id" => "11"}, {"id" => "2", "author_id" => "10"}]}, data)
      end

      def test_a_resource_that_refers_to_nothing_included_keeps_nothing
        data, problems, query = @includes.state_of([post({"geo" => {"place_id" => "p2"}})])

        assert_equal [{}, [nil], QUERY], [data, problems.map(&:resource_id), query]
      end

      def test_a_resource_keeps_the_problems_about_what_it_and_what_it_keeps_refer_to_or_about_nothing
        assert_equal ["9", "12", nil], resource_ids(post({"author_id" => "12", "in_reply_to_user_id" => "9"}))
        assert_equal ["9", nil], resource_ids(User.new({"id" => "9"}))
        assert_equal [nil], resource_ids(post({"referenced_tweets" => [{"type" => "quoted", "id" => "4"}]}))
        assert_equal ["9", "12", nil], resource_ids(post({"referenced_tweets" => [{"type" => "quoted", "id" => "12"}], "author_id" => "9"}))
      end

      def test_the_problems_kept_are_the_problems_themselves
        problems = @includes.state_of([post({"author_id" => "9"})])[1]

        assert_equal @includes.problems.values_at(0, 2), problems
        assert_same @includes.problems.first, problems.first
      end

      def test_objects_that_refer_to_each_other_are_kept_once
        includes = Includes.new({"users" => [{"id" => "9", "pinned_tweet_id" => "3"}], "tweets" => [{"id" => "3", "author_id" => "9"}]})

        assert_equal({"users" => [{"id" => "9", "pinned_tweet_id" => "3"}], "tweets" => [{"id" => "3", "author_id" => "9"}]}, includes.state_of([post({"author_id" => "9"})]).first)
      end

      def test_every_object_of_an_identifier_is_kept_in_the_order_it_was_included
        includes = Includes.new({"users" => [{"id" => "9", "name" => "first"}, {"id" => "8"}, {"id" => "9", "name" => "second"}]})
        data, = includes.state_of([post({"author_id" => "9", "in_reply_to_user_id" => "8"})])

        assert_equal({"users" => [{"id" => "9", "name" => "first"}, {"id" => "8"}, {"id" => "9", "name" => "second"}]}, data)
        assert_equal "first", Includes.new(data).resolve(User, "9", client: nil).attrs["name"]
      end

      def test_objects_kept_by_several_resources_are_kept_in_the_order_they_were_included
        data, = @includes.state_of([post({"author_id" => "11"}), post({"author_id" => "10"}), post({"author_id" => "11"})])

        assert_equal({"users" => [{"id" => "10"}, {"id" => "11"}]}, data)
      end

      def test_posts_are_kept_under_the_key_the_response_included_them_by
        includes = Includes.new({"posts" => [{"id" => "2"}], "tweets" => [{"id" => "2", "text" => "old"}]})

        assert_equal({"posts" => [{"id" => "2"}]}, includes.state_of([post({"referenced_posts" => [{"type" => "quoted", "id" => "2"}]})]).first)
      end

      def test_objects_are_kept_by_the_identifier_of_their_class
        includes = Includes.new({"media" => [{"id" => "3_1"}, {"media_key" => "3_1"}]})

        assert_equal({"media" => [{"media_key" => "3_1"}]}, includes.state_of([post({"attachments" => {"media_keys" => ["3_1"]}})]).first)
      end

      private

      def post(attrs) = Post.__send__(:build, {"id" => "1"}.merge(attrs), includes: @includes)

      def resource_ids(resource) = @includes.state_of([resource])[1].map { |problem| problem.to_h["resource_id"] }

      def problem(id) = Problem.new({"title" => "Not Found Error", "resource_id" => id}.compact)
    end
  end
end
