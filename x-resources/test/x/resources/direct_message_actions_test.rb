# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class DirectMessageActionsTest < Minitest::Test
    cover DirectMessage
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:BatchFinders)
    cover Resources.const_get(:Shape)

    def setup
      @client = FakeClient.new
      @includes = Resources.const_get(:Includes).new({"users" => [{"id" => "9", "username" => "me"}, {"id" => "8", "username" => "friend"}]})
    end

    def test_fields_key
      assert_equal "dm_event.fields", DirectMessage.__send__(:fields_key)
    end

    def test_offers_no_batch_lookup
      refute_respond_to DirectMessage, :find_all
      refute_respond_to DirectMessage, :hydrate_all
    end

    def test_delete
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

      assert DirectMessage.delete(DirectMessage.new({"id" => "1"}), client: @client)
      assert DirectMessage.delete(1, client: @client)
      assert_equal %w[dm_events/1 dm_events/1], @client.paths
    end

    def test_delete_reports_only_true
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => "yes"}})

      refute DirectMessage.delete("1", client: @client)
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

      assert_same true, DirectMessage.delete("1", client: @client)
    end

    def test_delete_not_deleted
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => false}})

      refute DirectMessage.delete("1", client: @client)
    end

    def test_delete_without_body
      @client.stub(:delete, "dm_events/1", nil)

      refute DirectMessage.delete("1", client: @client)
    end

    def test_delete_instance
      @client.stub(:delete, "dm_events/1", {"data" => {"deleted" => true}})

      assert DirectMessage.new({"id" => "1"}, client: @client).delete
      assert_equal ["dm_events/1"], @client.paths
    end

    def test_delete_without_client
      assert_raises(MissingClient) { DirectMessage.new({"id" => "1"}).delete }
    end

    def test_group
      assert_predicate DirectMessage.new({"id" => "1", "dm_conversation_id" => "1582838223204016129"}), :group?
      refute_predicate DirectMessage.new({"id" => "1", "dm_conversation_id" => "8-9"}), :group?
      refute_predicate DirectMessage.new({"id" => "1"}), :group?
    end

    def test_a_conversation_identifier_that_is_not_one_raises
      [1, ["8-9"], "", "8-", "8-9-10", "a-9", " 9", "9\n"].each do |value|
        message = DirectMessage.new({"id" => "1", "dm_conversation_id" => value})
        error = assert_raises(InvalidAttribute) { message.group? }

        assert_equal "X::DirectMessage#dm_conversation_id cannot be read from #{value.inspect}", error.message
        assert_equal "#{value.inspect} is not a conversation identifier", error.cause.message
        assert_raises(InvalidAttribute) { message.peer("9") }
      end
    end
  end
end
