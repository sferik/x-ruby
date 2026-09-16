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

      def test_delete_list
        @client.stub(:delete, "lists/1", {"data" => {"deleted" => true}})

        assert @client.delete_list("1")
        assert_equal ["lists/1"], @client.paths
      end

      def test_delete_list_not_deleted
        @client.stub(:delete, "lists/1", {"data" => {"deleted" => false}})

        refute @client.delete_list(List.new({"id" => "1"}))
      end
    end
  end
end
