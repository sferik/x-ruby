# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class IncludedHydrationTest < Minitest::Test
    cover Objects::Includes
    cover Resource
    cover Poll
    cover Place
    cover Objects::Pages
    cover Objects::Finders
    cover Objects::BatchFinders

    POST = {"id" => "1", "text" => "hi", "author_id" => "9", "geo" => {"place_id" => "p1"},
            "attachments" => {"media_keys" => ["3_1"], "poll_ids" => ["7", "8"]},
            "referenced_posts" => [{"type" => "quoted", "id" => "2"}]}.freeze
    INCLUDES = {"polls" => [{"id" => "7", "options" => []}], "places" => [{"id" => "p1", "full_name" => "Here"}],
                "media" => [{"media_key" => "3_1", "type" => "photo"}], "users" => [{"id" => "9", "username" => "sferik"}],
                "posts" => [{"id" => "2", "text" => "quoted"}]}.freeze

    def setup
      @client = FakeClient.new
    end

    def post(**params)
      @client.stub(:get, "tweets/1", {"data" => POST, "includes" => INCLUDES})
      @client.find_post!(1, **params)
    end

    def test_a_poll_a_place_and_media_included_with_every_field_are_hydrated
      post = post()

      assert_equal [true, true, true], [post.polls.first.hydrated?, post.place.hydrated?, post.media.first.hydrated?]
    end

    def test_an_included_poll_place_and_media_hydrate_without_a_request
      included = post.then { |found| [found.polls.first, found.place, found.media.first] }

      assert_equal included, included.map(&:hydrate)
      assert_equal ["tweets/1"], @client.paths
    end

    def test_a_request_that_narrows_the_fields_of_a_poll_leaves_it_to_be_hydrated
      post = post("poll.fields": "id", "place.fields": "id", "media.fields": "media_key")

      assert_equal [false, false, false], [post.polls.first.hydrated?, post.place.hydrated?, post.media.first.hydrated?]
    end

    def test_a_resource_that_expands_resources_of_its_own_is_not_hydrated_when_included
      post = post()

      assert_equal [false, false], [post.author.hydrated?, post.quoted.hydrated?]
    end

    def test_a_poll_the_response_did_not_include_is_a_stub
      assert_equal [true, false], post.polls.map(&:hydrated?)
    end

    def test_a_response_built_without_its_query_hydrates_nothing_it_included
      post = Post.resource_from_response({"data" => POST, "includes" => INCLUDES}, client: @client, hydrated: true)

      refute_predicate post.polls.first, :hydrated?
    end

    def test_a_poll_included_in_a_batch_lookup_or_a_page_is_hydrated
      @client.stub(:get, "tweets", {"data" => [POST], "includes" => INCLUDES})
      @client.stub(:get, "tweets/search/recent", {"data" => [POST], "includes" => INCLUDES})

      assert_predicate @client.find_all_posts([1]).first.polls.first, :hydrated?
      assert_predicate @client.search_posts("ruby").first.polls.first, :hydrated?
      assert_predicate Post.__send__(:lookup_all, "tweets", client: @client).first.polls.first, :hydrated?
    end

    def test_the_query_of_the_includes_is_a_frozen_copy
      query = {"poll.fields" => Poll::FIELDS.join(",")}
      includes = Objects::Includes.new(INCLUDES, query:)
      query["poll.fields"] = "id"

      assert_predicate includes.resolve(Poll, "7", client: @client), :hydrated?
    end

    def test_polls_and_places_request_every_field
      assert_equal [{"poll.fields" => Poll::FIELDS}, {"place.fields" => Place::FIELDS}], [Poll.default_params, Place.default_params]
    end
  end
end
