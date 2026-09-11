require_relative "../../test_helper"

module X
  class PostActionsTest < Minitest::Test
    cover Post

    def setup
      @client = FakeClient.new
      @post = Post.new({"id" => "1"}, client: @client)
    end

    def test_delete
      @client.stub(:delete, "tweets/1", {"data" => {"deleted" => true}})

      assert @post.delete
      assert_equal ["tweets/1"], @client.paths
    end

    def test_delete_not_deleted
      @client.stub(:delete, "tweets/1", {"data" => {"deleted" => false}})

      refute @post.delete
    end

    def test_delete_without_body
      @client.stub(:delete, "tweets/1", nil)

      assert_same false, @post.delete
    end

    def test_delete_without_client
      error = assert_raises(ArgumentError) { Post.new({"id" => "1"}).delete }

      assert_equal "X::Post has no client", error.message
    end
  end
end
