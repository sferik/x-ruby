# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class SpaceTest < Minitest::Test
    cover Space

    def setup
      @client = FakeClient.new
      includes = Resources.const_get(:Includes).new({"users" => [{"id" => "9", "username" => "sferik"}],
                                                   "topics" => [{"id" => "848920371311001600", "name" => "Technology", "description" => "All about technology"}]})
      @space = Space.__send__(:build, {"id" => "1", "title" => "Ruby", "state" => "live", "lang" => "en",
                          "created_at" => "2024-01-02T03:04:05.000Z", "started_at" => "2024-01-02T03:05:05.000Z",
                          "ended_at" => "2024-01-02T04:04:05.000Z", "scheduled_start" => "2024-01-02T03:00:00.000Z",
                          "updated_at" => "2024-01-02T03:06:05.000Z", "is_ticketed" => true, "participant_count" => 2,
                          "subscriber_count" => 3, "creator_id" => "9", "host_ids" => ["9"], "speaker_ids" => %w[9 8],
                          "invited_user_ids" => ["7"], "topic_ids" => ["848920371311001600"]}, client: @client, includes:)
    end

    def test_fields_key
      assert_equal "space.fields", Space.__send__(:fields_key)
    end

    def test_class_configuration
      assert_equal "spaces", Space.__send__(:endpoint)
      assert_nil Space.__send__(:includes_key)
      assert_equal({"space.fields" => Space::FIELDS, "user.fields" => User::FIELDS, "topic.fields" => Topic::FIELDS, "expansions" => Space::EXPANSIONS}, Space.default_params)
    end

    def test_search
      cursor = Space.search("ruby", client: @client, state: "live")

      assert_equal ["spaces/search", Space, "ruby", "live", 100], [cursor.__send__(:path), cursor.resource_class, cursor.__send__(:params)["query"], cursor.__send__(:params)["state"], cursor.__send__(:params)["max_results"]]
      assert_equal Space::FIELDS.join(","), cursor.__send__(:params)["space.fields"]
      assert_same @client, cursor.client
    end

    def test_search_reads_the_one_page_the_api_returns
      @client.stub(:get, "spaces/search", {"data" => [{"id" => "1DXxyRYNejbKM", "title" => "Ruby"}], "meta" => {"result_count" => 1}})

      assert_equal ["Ruby"], Space.search("ruby", client: @client, max_results: 10).map(&:title)
      assert_equal [{"query" => "ruby", "max_results" => "10"}], @client.queries.map { |query| query.slice("query", "max_results") }
    end

    def test_attributes
      assert_equal "Ruby", @space.title
      assert_equal "live", @space.state
      assert_equal "en", @space.lang
      assert_equal 2, @space.participant_count
      assert_equal 3, @space.subscriber_count
    end

    def test_times
      assert_equal Time.utc(2024, 1, 2, 3, 4, 5), @space.created_at
      assert_equal Time.utc(2024, 1, 2, 3, 5, 5), @space.started_at
      assert_equal Time.utc(2024, 1, 2, 4, 4, 5), @space.ended_at
      assert_equal Time.utc(2024, 1, 2, 3, 0, 0), @space.scheduled_start
      assert_equal Time.utc(2024, 1, 2, 3, 6, 5), @space.updated_at
    end

    def test_ticketed
      assert @space.ticketed
      assert_predicate @space, :ticketed?
      assert_instance_of FalseClass, Space.new({"id" => "1"}).ticketed?
      assert_instance_of FalseClass, Space.new({"id" => "1", "is_ticketed" => false}).ticketed?
    end

    def test_ticketed_is_read_from_the_field_the_api_names_is_ticketed
      assert_nil Space.new({"id" => "1"}).ticketed
      refute_respond_to @space, :is_ticketed
    end

    def test_ids
      assert_equal 9, @space.creator_id
      assert_equal [9], @space.host_ids
      assert_equal [9, 8], @space.speaker_ids
      assert_equal [7], @space.invited_user_ids
      assert_equal [848920371311001600], @space.topic_ids
    end

    def test_references
      assert_equal "sferik", @space.creator.username
      assert_equal ["sferik"], @space.hosts.map(&:username)
      assert_equal [9, 8], @space.speakers.map(&:id)
      assert_equal [7], @space.invited_users.map(&:id)
    end

    def test_topics
      assert_equal [[848920371311001600, "Technology"]], @space.topics.map { |topic| [topic.id, topic.name] }
    end

    def test_posts
      assert_equal "spaces/1/tweets", @space.posts.__send__(:path)
      assert_equal "spaces/1/tweets", @space.tweets.__send__(:path)
      assert_equal Post, @space.posts.resource_class
      assert_same @client, @space.posts.client
    end

    def test_posts_params
      assert_equal 100, @space.posts.__send__(:params)["max_results"]
      assert_equal 5, @space.posts(max_results: 5).__send__(:params)["max_results"]
    end

    def test_find
      @client.stub(:get, "spaces/1", {"data" => {"id" => "1", "title" => "Ruby"}})

      assert_equal "Ruby", Space.find("1", client: @client).title
      assert_equal Space::FIELDS.join(","), @client.queries.first["space.fields"]
    end
  end
end
