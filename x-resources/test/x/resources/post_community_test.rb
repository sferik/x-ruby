# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PostCommunityTest < Minitest::Test
    cover Post

    def setup
      @client = FakeClient.new
    end

    def test_community
      post = Post.new({"id" => "1", "community_id" => "7"}, client: @client)

      assert_equal 7, post.community_id
      assert_equal Community.from_id(7), post.community
      assert_predicate post.community, :stub?
      assert_same @client, post.community.client
    end

    def test_no_community
      assert_nil Post.new({"id" => "1"}).community
    end

    def test_community_hydrates
      @client.stub(:get, "communities/7", {"data" => {"id" => "7", "name" => "Rubyists"}})

      assert_equal "Rubyists", Post.new({"id" => "1", "community_id" => "7"}, client: @client).community.hydrate.name
    end

    def test_community_id_is_a_default_field
      assert_includes Post.default_params["post.fields"], "community_id"
    end
  end
end
