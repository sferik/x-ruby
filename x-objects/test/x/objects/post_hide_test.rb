require_relative "../../test_helper"

module X
  class PostHideTest < Minitest::Test
    cover Post
    cover Objects::PostWrites

    def setup
      @client = FakeClient.new
      @reply = Post.new({"id" => "1"}, client: @client)
    end

    def test_hide
      @client.stub(:put, "tweets/1/hidden", {"data" => {"hidden" => true}})

      assert @reply.hide
      assert_equal [{method: :put, path: "tweets/1/hidden", query: {}, body: {hidden: true}.to_json}], @client.requests
    end

    def test_hide_not_hidden
      @client.stub(:put, "tweets/1/hidden", {"data" => {"hidden" => false}})

      refute @reply.hide
    end

    def test_hide_without_body
      @client.stub(:put, "tweets/1/hidden", nil)

      assert_same false, @reply.hide
    end

    def test_unhide
      @client.stub(:put, "tweets/1/hidden", {"data" => {"hidden" => false}})

      assert @reply.unhide
      assert_equal [{method: :put, path: "tweets/1/hidden", query: {}, body: {hidden: false}.to_json}], @client.requests
    end

    def test_unhide_still_hidden
      @client.stub(:put, "tweets/1/hidden", {"data" => {"hidden" => true}})

      refute Post.unhide("1", client: @client)
    end

    def test_unhide_without_body
      @client.stub(:put, "tweets/1/hidden", {})

      assert_same false, @reply.unhide
    end

    def test_hide_without_client
      assert_raises(ArgumentError) { Post.new({"id" => "1"}).hide }
      assert_raises(ArgumentError) { Post.new({"id" => "1"}).unhide }
    end
  end
end
