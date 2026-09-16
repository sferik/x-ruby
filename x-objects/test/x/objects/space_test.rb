require_relative "../../test_helper"

module X
  class SpaceTest < Minitest::Test
    cover Space

    def setup
      @client = FakeClient.new
      includes = Objects::Includes.new({"users" => [{"id" => "9", "username" => "sferik"}]})
      @space = Space.new({"id" => "1", "title" => "Ruby", "state" => "live", "lang" => "en",
                          "created_at" => "2024-01-02T03:04:05.000Z", "started_at" => "2024-01-02T03:05:05.000Z",
                          "ended_at" => "2024-01-02T04:04:05.000Z", "scheduled_start" => "2024-01-02T03:00:00.000Z",
                          "updated_at" => "2024-01-02T03:06:05.000Z", "is_ticketed" => true, "participant_count" => 2,
                          "subscriber_count" => 3, "creator_id" => "9", "host_ids" => ["9"], "speaker_ids" => %w[9 8],
                          "invited_user_ids" => ["7"], "topic_ids" => ["t1"]}, client: @client, includes:)
    end

    def test_fields_key
      assert_equal "space.fields", Space.fields_key
    end

    def test_class_configuration
      assert_equal "spaces", Space.endpoint
      assert_nil Space.includes_key
      assert_equal({"space.fields" => Space::FIELDS, "user.fields" => User::FIELDS, "expansions" => Space::EXPANSIONS}, Space.default_params)
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
      assert @space.is_ticketed
      assert_predicate @space, :ticketed?
      assert_instance_of FalseClass, Space.new({"id" => "1"}).ticketed?
      assert_instance_of FalseClass, Space.new({"id" => "1", "is_ticketed" => false}).ticketed?
    end

    def test_ids
      assert_equal 9, @space.creator_id
      assert_equal [9], @space.host_ids
      assert_equal [9, 8], @space.speaker_ids
      assert_equal [7], @space.invited_user_ids
      assert_equal ["t1"], @space.topic_ids
    end

    def test_references
      assert_equal "sferik", @space.creator.username
      assert_equal ["sferik"], @space.hosts.map(&:username)
      assert_equal [9, 8], @space.speakers.map(&:id)
      assert_equal [7], @space.invited_users.map(&:id)
    end

    def test_posts
      assert_equal "spaces/1/tweets", @space.posts.path
      assert_equal "spaces/1/tweets", @space.tweets.path
      assert_equal Post, @space.posts.klass
      assert_same @client, @space.posts.client
    end

    def test_posts_params
      assert_equal 100, @space.posts.params["max_results"]
      assert_equal 5, @space.posts(max_results: 5).params["max_results"]
    end

    def test_find
      @client.stub(:get, "spaces/1", {"data" => {"id" => "1", "title" => "Ruby"}})

      assert_equal "Ruby", Space.find("1", client: @client).title
      assert_equal Space::FIELDS.join(","), @client.queries.first["space.fields"]
    end
  end
end
