# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class TopicTest < Minitest::Test
    cover Topic

    def setup
      @topic = Topic.new({"id" => "848920371311001600", "name" => "Technology", "description" => "All about technology"})
    end

    def test_class_configuration
      assert_equal "topics", Topic.__send__(:includes_key)
      assert_nil Topic.__send__(:endpoint)
      assert_equal({"topic.fields" => %w[description id name]}, Topic.default_params)
    end

    def test_attributes
      assert_equal [848920371311001600, "Technology", "All about technology"], [@topic.id, @topic.name, @topic.description]
    end

    def test_a_topic_a_space_included_with_every_field_is_hydrated
      client = FakeClient.new
      client.stub(:get, "spaces/1", {"data" => {"id" => "1", "topic_ids" => ["848920371311001600"]},
                                     "includes" => {"topics" => [{"id" => "848920371311001600", "name" => "Technology"}]}})
      topic = Space.find!("1", client:).topics.first

      assert_equal [true, "Technology"], [topic.hydrated?, topic.name]
      assert_same topic, topic.hydrate
    end

    def test_a_topic_a_space_included_with_fewer_fields_is_not_hydrated
      client = FakeClient.new
      client.stub(:get, "spaces/1", {"data" => {"id" => "1", "topic_ids" => ["848920371311001600"]},
                                     "includes" => {"topics" => [{"id" => "848920371311001600"}]}})

      refute_predicate Space.find!("1", client:, "topic.fields": "id").topics.first, :hydrated?
    end

    def test_a_topic_the_response_did_not_include_is_a_stub
      topic = Space.new({"id" => "1", "topic_ids" => ["848920371311001600"]}).topics.first

      assert_equal [848920371311001600, false], [topic.id, topic.hydrated?]
      assert_raises(UnsupportedOperation) { topic.hydrate }
    end
  end
end
