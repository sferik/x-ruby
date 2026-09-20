require_relative "../../test_helper"

module X
  module Objects
    class APICommunityLookupsTest < Minitest::Test
      cover API::Lookups

      def setup
        @client = FakeClient.new
      end

      def test_find_community
        @client.stub(:get, "communities/7", {"data" => {"id" => "7", "name" => "Rubyists"}})
        community = @client.find_community(7, "community.fields": "id")

        assert_equal "Rubyists", community.name
        assert_same @client, community.client
        assert_equal "id", @client.queries.first["community.fields"]
      end

      def test_find_community_bang
        @client.stub(:get, "communities/7", {"data" => {"id" => "7", "name" => "Rubyists"}})
        @client.stub(:get, "communities/8", {"errors" => []})

        assert_equal "Rubyists", @client.find_community!(7, "community.fields": "id").name
        assert_equal "id", @client.queries.first["community.fields"]
        assert_raises(MissingResource) { @client.find_community!(8) }
      end

      def test_search_communities
        cursor = @client.search_communities("ruby", max_results: 10)

        assert_equal "communities/search", cursor.path
        assert_equal ["ruby", 10], [cursor.params["query"], cursor.params["max_results"]]
        assert_same @client, cursor.client
      end
    end
  end
end
