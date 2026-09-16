require_relative "../../test_helper"

module X
  class UserRelationshipActionsTest < Minitest::Test
    cover Objects::Relationships

    def setup
      @client = FakeClient.new
      @me = User.new({"id" => "9"}, client: @client)
    end

    def test_block
      @client.stub(:post, "users/9/blocking", {"data" => {"blocking" => true}})

      assert @me.block(User.new({"id" => "1"}))
      assert_equal [{method: :post, path: "users/9/blocking", query: {}, body: {target_user_id: "1"}.to_json}], @client.requests
    end

    def test_block_not_blocking
      @client.stub(:post, "users/9/blocking", {"data" => {"blocking" => false}})

      refute @me.block(1)
    end

    def test_block_without_body
      @client.stub(:post, "users/9/blocking", nil)

      assert_same false, @me.block("1")
    end

    def test_unblock
      @client.stub(:delete, "users/9/blocking/1", {"data" => {"blocking" => false}})

      assert @me.unblock(User.new({"id" => "1"}))
      assert_equal ["users/9/blocking/1"], @client.paths
    end

    def test_unblock_still_blocking
      @client.stub(:delete, "users/9/blocking/1", {"data" => {"blocking" => true}})

      refute @me.unblock("1")
    end

    def test_unblock_without_body
      @client.stub(:delete, "users/9/blocking/1", nil)

      refute @me.unblock(1)
    end

    def test_mute
      @client.stub(:post, "users/9/muting", {"data" => {"muting" => true}})

      assert @me.mute(User.new({"id" => "1"}))
      assert_equal [{method: :post, path: "users/9/muting", query: {}, body: {target_user_id: "1"}.to_json}], @client.requests
    end

    def test_mute_not_muting
      @client.stub(:post, "users/9/muting", {"data" => {"muting" => false}})

      refute @me.mute(1)
    end

    def test_unmute
      @client.stub(:delete, "users/9/muting/1", {"data" => {"muting" => false}})

      assert @me.unmute(User.new({"id" => "1"}))
      assert_equal ["users/9/muting/1"], @client.paths
    end

    def test_unmute_still_muting
      @client.stub(:delete, "users/9/muting/1", {"data" => {"muting" => true}})

      refute @me.unmute("1")
    end

    def test_actions_report_the_named_state_only
      @client.stub(:post, "users/9/blocking", {"data" => {"muting" => true, "blocking" => false}})
      @client.stub(:delete, "users/9/muting/1", {"data" => {"blocking" => false, "muting" => true}})

      refute @me.block(1)
      refute @me.unmute(1)
    end
  end
end
