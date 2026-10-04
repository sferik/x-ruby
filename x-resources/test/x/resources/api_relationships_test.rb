# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Resources
    class APIRelationshipsTest < Minitest::Test
      cover Resources.const_get(:Actions)::Relationships
      cover Resources.const_get(:RelationWrites)

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      end

      def test_follow
        @client.stub(:post, "users/9/following", {"data" => {"following" => true, "pending_follow" => false}})

        assert @client.follow(User.new({"id" => "1"}))
        assert_equal({target_user_id: "1"}.to_json, @client.requests.last[:body])
        assert_equal "users/9/following", @client.paths.last
      end

      def test_follow_pending
        @client.stub(:post, "users/9/following", {"data" => {"following" => false, "pending_follow" => true}})

        assert @client.follow("1")
      end

      def test_follow_refused
        @client.stub(:post, "users/9/following", {"data" => {"following" => false, "pending_follow" => false}})

        assert_same false, @client.follow(1)
      end

      def test_follow_reports_only_a_state_of_true
        @client.stub(:post, "users/9/following", {"data" => {"following" => "true", "pending_follow" => 1}})

        assert_same false, @client.follow(1)
      end

      def test_follow_without_body
        @client.stub(:post, "users/9/following", nil)

        assert_same false, @client.follow("1")
      end

      def test_unfollow
        @client.stub(:delete, "users/9/following/1", {"data" => {"following" => false}})

        assert @client.unfollow(User.new({"id" => "1"}))
        assert_equal "users/9/following/1", @client.paths.last
      end

      def test_unfollow_still_following
        @client.stub(:delete, "users/9/following/1", {"data" => {"following" => true}})

        refute @client.unfollow("1")
      end

      def test_unfollow_without_body
        @client.stub(:delete, "users/9/following/1", nil)

        refute @client.unfollow(1)
      end

      def test_block
        @client.stub(:post, "users/9/blocking", {"data" => {"blocking" => true}})

        assert @client.block(User.new({"id" => "1"}))
        assert_equal({target_user_id: "1"}.to_json, @client.requests.last[:body])
        assert_equal "users/9/blocking", @client.paths.last
      end

      def test_block_not_blocking
        @client.stub(:post, "users/9/blocking", {"data" => {"blocking" => false}})

        refute @client.block("1")
      end

      def test_block_without_body
        @client.stub(:post, "users/9/blocking", nil)

        assert_same false, @client.block(1)
      end

      def test_unblock
        @client.stub(:delete, "users/9/blocking/1", {"data" => {"blocking" => false}})

        assert @client.unblock(User.new({"id" => "1"}))
        assert_equal "users/9/blocking/1", @client.paths.last
      end

      def test_unblock_still_blocking
        @client.stub(:delete, "users/9/blocking/1", {"data" => {"blocking" => true}})

        refute @client.unblock("1")
      end

      def test_unblock_without_body
        @client.stub(:delete, "users/9/blocking/1", nil)

        refute @client.unblock(1)
      end

      def test_mute
        @client.stub(:post, "users/9/muting", {"data" => {"muting" => true}})

        assert @client.mute(User.new({"id" => "1"}))
        assert_equal({target_user_id: "1"}.to_json, @client.requests.last[:body])
        assert_equal "users/9/muting", @client.paths.last
      end

      def test_mute_not_muting
        @client.stub(:post, "users/9/muting", {"data" => {"muting" => false}})

        refute @client.mute(1)
      end

      def test_unmute
        @client.stub(:delete, "users/9/muting/1", {"data" => {"muting" => false}})

        assert @client.unmute(User.new({"id" => "1"}))
        assert_equal "users/9/muting/1", @client.paths.last
      end

      def test_unmute_still_muting
        @client.stub(:delete, "users/9/muting/1", {"data" => {"muting" => true}})

        refute @client.unmute("1")
      end

      def test_actions_report_the_named_state_only
        @client.stub(:post, "users/9/blocking", {"data" => {"muting" => true, "blocking" => false}})
        @client.stub(:delete, "users/9/muting/1", {"data" => {"blocking" => false, "muting" => true}})

        refute @client.block(1)
        refute @client.unmute(1)
      end

      def test_actions_refuse_an_authenticated_user_whose_identifier_is_not_a_number
        @client.define_singleton_method(:current_user_id) { "9/following" }

        assert_equal "\"9/following\" is not an identifier: pass X::User, an Integer, or a String of digits", assert_raises(ArgumentError) { @client.follow(1) }.message
        assert_raises(ArgumentError) { @client.unfollow(1) }
        assert_empty @client.requests
      end
    end
  end
end
