require_relative "../../test_helper"

module X
  module Objects
    class APIListsTest < Minitest::Test
      cover API::Actions::Lists

      def setup
        @client = FakeClient.new
        @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      end

      def test_create_list
        @client.stub(:post, "lists", {"data" => {"id" => "1", "name" => "Rubyists"}})
        list = @client.create_list("Rubyists", private: true)

        assert_equal "Rubyists", list.name
        assert_same @client, list.client
        assert_equal({name: "Rubyists", private: true}.to_json, @client.requests.first[:body])
      end

      def test_update_list
        @client.stub(:put, "lists/1", {"data" => {"updated" => true}})

        assert @client.update_list("1", name: "Rubyists")
        assert_equal [{method: :put, path: "lists/1", query: {}, body: {name: "Rubyists"}.to_json}], @client.requests
      end

      def test_delete_list
        @client.stub(:delete, "lists/1", {"data" => {"deleted" => true}})

        assert @client.delete_list("1")
        assert_equal ["lists/1"], @client.paths
      end

      def test_delete_list_not_deleted
        @client.stub(:delete, "lists/1", {"data" => {"deleted" => false}})

        refute @client.delete_list(List.new({"id" => "1"}))
      end

      def test_follow_list
        @client.stub(:post, "users/9/followed_lists", {"data" => {"following" => true}})

        assert @client.follow_list(List.new({"id" => "1"}))
        assert_equal [{method: :post, path: "users/9/followed_lists", query: {}, body: {list_id: "1"}.to_json}], @client.requests.drop(1)
      end

      def test_unfollow_list
        @client.stub(:delete, "users/9/followed_lists/1", {"data" => {"following" => false}})

        assert @client.unfollow_list("1")
        assert_equal "users/9/followed_lists/1", @client.paths.last
      end

      def test_pin_list
        @client.stub(:post, "users/9/pinned_lists", {"data" => {"pinned" => true}})

        assert @client.pin_list("1")
        assert_equal [{method: :post, path: "users/9/pinned_lists", query: {}, body: {list_id: "1"}.to_json}], @client.requests.drop(1)
      end

      def test_unpin_list
        @client.stub(:delete, "users/9/pinned_lists/1", {"data" => {"pinned" => false}})

        assert @client.unpin_list("1")
        assert_equal "users/9/pinned_lists/1", @client.paths.last
      end
    end
  end
end
