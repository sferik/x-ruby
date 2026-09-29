# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ResourceProblemsTest < Minitest::Test
    cover Resource
    cover Objects::Attributes
    cover Objects::Includes
    cover Post
    cover DirectMessage

    AUTHOR_MISSING = {"title" => "Not Found Error", "detail" => "Could not find user with author_id: [5].",
                      "type" => "https://api.x.com/2/problems/resource-not-found", "resource_type" => "user",
                      "resource_id" => "5", "parameter" => "author_id", "value" => "5"}.freeze
    GENERAL = {"title" => "Something went wrong"}.freeze

    def posts(*data, errors: [AUTHOR_MISSING])
      Post.collection_from_response({"data" => data, "errors" => errors}, client: nil)
    end

    def details(resources) = resources.map { |resource| resource.problems.map(&:title) }

    def test_a_post_reports_the_missing_author_it_refers_to_and_no_other_post_does
      first, second = posts({"id" => "1", "author_id" => "3"}, {"id" => "2", "author_id" => "5"})

      assert_empty first.problems
      assert_equal [AUTHOR_MISSING], second.problems.map(&:to_h)
      assert_predicate first.problems, :frozen?
      assert_predicate second.problems, :frozen?
    end

    def test_a_problem_about_the_resource_itself
      problem = {"title" => "Authorization Error", "resource_type" => "tweet", "resource_id" => "2"}

      assert_equal [[], ["Authorization Error"]], details(posts({"id" => "1"}, {"id" => "2"}, errors: [problem]))
    end

    def test_a_problem_named_by_its_value_alone
      problem = {"title" => "Not Found Error", "parameter" => "in_reply_to_user_id", "value" => "5"}

      assert_equal [["Not Found Error"], []], details(posts({"id" => "1", "in_reply_to_user_id" => "5"}, {"id" => "2"}, errors: [problem]))
    end

    def test_a_problem_that_names_no_resource_is_reported_by_every_resource
      assert_equal [["Something went wrong"]] * 2, details(posts({"id" => "1"}, {"id" => "2"}, errors: [GENERAL]))
    end

    def test_a_problem_about_a_list_of_references
      problem = {"title" => "Not Found Error", "resource_type" => "media", "resource_id" => "3_9", "value" => "3_9"}
      first, second = posts({"id" => "1", "attachments" => {"media_keys" => %w[3_1 3_9]}}, {"id" => "2", "attachments" => {"media_keys" => ["3_2"]}}, errors: [problem])

      assert_equal [["Not Found Error"], []], details([first, second])
    end

    def test_a_problem_about_a_referenced_post
      problem = {"title" => "Not Found Error", "resource_type" => "tweet", "resource_id" => "9", "value" => "9"}

      assert_equal [["Not Found Error"], []], details(posts({"id" => "1", "referenced_posts" => [{"type" => "quoted", "id" => "9"}]}, {"id" => "2"}, errors: [problem]))
      assert_equal [["Not Found Error"], []], details(posts({"id" => "1", "referenced_tweets" => [{"type" => "quoted", "id" => "9"}]}, {"id" => "2"}, errors: [problem]))
    end

    def test_a_problem_about_a_post_a_direct_message_refers_to
      problem = {"title" => "Not Found Error", "resource_type" => "tweet", "resource_id" => "9"}
      messages = DirectMessage.collection_from_response({"data" => [{"id" => "1", "referenced_posts" => [{"id" => "9"}]}, {"id" => "2", "sender_id" => "3"}], "errors" => [problem]}, client: nil)

      assert_equal [["Not Found Error"], []], details(messages)
    end

    def test_a_reference_under_another_name_after_tweets
      problem = {"title" => "Not Found Error", "resource_type" => "tweet", "resource_id" => "9"}
      user = User.resource_from_response({"data" => {"id" => "1", "pinned_tweet_id" => "9"}, "errors" => [problem]}, client: nil)

      assert_equal ["Not Found Error"], user.problems.map(&:title)
    end

    def test_a_response_that_holds_a_reference_as_something_other_than_an_object_names_no_reference
      problem = {"title" => "Not Found Error", "resource_type" => "media", "resource_id" => "3_9"}

      assert_equal [[]] * 2, details(posts({"id" => "1", "attachments" => "3_9"}, {"id" => "2", "attachments" => ["3_9"]}, errors: [problem]))
      assert_equal [[]], details(posts({"id" => "1", "referenced_posts" => "9"}, errors: [problem]))
    end

    def test_a_referenced_post_without_an_identifier_names_none
      problem = {"title" => "Not Found Error", "resource_type" => "tweet", "resource_id" => "9"}

      assert_equal [[]], details(posts({"id" => "1", "referenced_posts" => [{"type" => "quoted"}, "9x"]}, errors: [problem]))
    end

    def test_an_included_resource_reports_the_problems_about_it
      problem = {"title" => "Not Found Error", "resource_type" => "tweet", "resource_id" => "9"}
      post = Post.resource_from_response({"data" => {"id" => "1", "author_id" => "2"}, "errors" => [problem],
                                          "includes" => {"users" => [{"id" => "2", "pinned_post_id" => "9"}]}}, client: nil)

      assert_equal [[], ["Not Found Error"]], details([post, post.author])
    end

    def widget_class
      Class.new(Resource) do
        reference :owner, :User, key: %w[owner_id], tweet_key: %w[owner_tweet_id]
        references :members, :User, key: %w[meta member_ids]
      end
    end

    def test_the_references_a_class_declares_name_the_problems_of_its_resources
      problems = [{"title" => "Owner", "resource_id" => "3"}, {"title" => "Member", "value" => "4"}, {"title" => "Other", "resource_id" => "5"},
        {"title" => "Named twice", "resource_id" => "6", "value" => "sferik"}]
      widget = widget_class.__send__(:build, {"id" => "1", "owner_tweet_id" => "3", "meta" => {"member_ids" => %w[4 6]}},
        includes: Objects::Includes.new(problems: problems.map { |problem| Problem.new(problem) }))

      assert_equal [nil, "3", "4", "6"], widget.class.__send__(:referenced_ids, widget.attrs)
      assert_equal ["Owner", "Member", "Named twice"], widget.problems.map(&:title)
      assert_predicate Objects::Includes.new(problems: [Problem.new({})]).problems, :frozen?
    end

    def test_identifiers_the_attributes_hold_as_numbers
      assert_equal [9], User.__send__(:referenced_ids, {"id" => 1, "pinned_post_id" => 9}).compact
    end

    def test_a_subclass_refers_to_what_its_class_refers_to_and_what_it_declares
      klass = widget_class
      subclass = Class.new(klass) { reference :parent, :User, key: %w[parent_id] }

      assert_equal [%w[owner_id], %w[owner_tweet_id], %w[meta member_ids]], klass.__send__(:reference_keys)
      assert_equal [*klass.__send__(:reference_keys), %w[parent_id]], subclass.__send__(:reference_keys)
      assert_empty Class.new { extend Objects::Attributes }.__send__(:reference_keys)
    end

    def test_the_keys_of_the_references_of_a_class
      assert_equal [%w[owner_id]], List.__send__(:reference_keys)
      assert_includes Post.__send__(:reference_keys), %w[referenced_tweets]
      assert_equal [%w[pinned_post_id], %w[pinned_tweet_id], %w[most_recent_post_id], %w[most_recent_tweet_id], %w[affiliation user_id]],
        User.__send__(:reference_keys)
      assert_empty Resource.__send__(:reference_keys)
    end
  end
end
