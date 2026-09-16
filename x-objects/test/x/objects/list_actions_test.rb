require_relative "../../test_helper"

module X
  class ListActionsTest < Minitest::Test
    cover List

    def setup
      @client = FakeClient.new
      @list = List.new({"id" => "1"}, client: @client)
    end

    def test_fields_key
      assert_equal "list.fields", List.fields_key
    end

    def test_create
      @client.stub(:post, "lists", {"data" => {"id" => "1", "name" => "Rubyists"}})
      list = List.create("Rubyists", client: @client, description: "People who write Ruby", private: true)

      assert_equal "Rubyists", list.name
      refute_predicate list, :hydrated?
      assert_same @client, list.client
      assert_equal [{method: :post, path: "lists", query: {}, body: {name: "Rubyists", description: "People who write Ruby", private: true}.to_json}], @client.requests
    end

    def test_create_without_data
      @client.stub(:post, "lists", {"errors" => []})

      assert_nil List.create("Rubyists", client: @client)
    end

    def test_delete
      @client.stub(:delete, "lists/1", {"data" => {"deleted" => true}})

      assert List.delete(List.new({"id" => "1"}), client: @client)
      assert List.delete(1, client: @client)
      assert_equal %w[lists/1 lists/1], @client.paths
    end

    def test_delete_reports_only_true
      @client.stub(:delete, "lists/1", {"data" => {"deleted" => "yes"}})

      refute List.delete("1", client: @client)
      @client.stub(:delete, "lists/1", {"data" => {"deleted" => true}})

      assert_same true, List.delete("1", client: @client)
    end

    def test_add_member_reports_only_true
      @client.stub(:post, "lists/1/members", {"data" => {"is_member" => "yes"}})

      refute @list.add_member(2)
      @client.stub(:post, "lists/1/members", {"data" => {"is_member" => true}})

      assert_same true, @list.add_member(2)
    end

    def test_remove_member_reports_only_false
      @client.stub(:delete, "lists/1/members/2", {"data" => {"is_member" => "no"}})

      refute @list.remove_member(2)
      @client.stub(:delete, "lists/1/members/2", {"data" => {"is_member" => false}})

      assert_same true, @list.remove_member(2)
    end

    def test_delete_not_deleted
      @client.stub(:delete, "lists/1", {"data" => {"deleted" => false}})

      refute List.delete("1", client: @client)
    end

    def test_delete_without_body
      @client.stub(:delete, "lists/1", nil)

      refute List.delete("1", client: @client)
    end

    def test_delete_instance
      @client.stub(:delete, "lists/1", {"data" => {"deleted" => true}})

      assert @list.delete
      assert_equal ["lists/1"], @client.paths
    end

    def test_delete_without_client
      assert_raises(ArgumentError) { List.new({"id" => "1"}).delete }
    end

    def test_add_member
      @client.stub(:post, "lists/1/members", {"data" => {"is_member" => true}})

      assert @list.add_member(User.new({"id" => "2"}))
      assert_equal [{method: :post, path: "lists/1/members", query: {}, body: {user_id: "2"}.to_json}], @client.requests
    end

    def test_add_member_not_a_member
      @client.stub(:post, "lists/1/members", {"data" => {"is_member" => false}})

      refute @list.add_member(2)
    end

    def test_add_member_without_body
      @client.stub(:post, "lists/1/members", nil)

      assert_same false, @list.add_member("2")
    end

    def test_remove_member
      @client.stub(:delete, "lists/1/members/2", {"data" => {"is_member" => false}})

      assert @list.remove_member(User.new({"id" => "2"}))
      assert_equal ["lists/1/members/2"], @client.paths
    end

    def test_remove_member_still_a_member
      @client.stub(:delete, "lists/1/members/2", {"data" => {"is_member" => true}})

      refute @list.remove_member("2")
    end

    def test_remove_member_without_body
      @client.stub(:delete, "lists/1/members/2", nil)

      refute @list.remove_member(2)
    end

    def test_members_without_client
      assert_raises(ArgumentError) { List.new({"id" => "1"}).add_member(2) }
      assert_raises(ArgumentError) { List.new({"id" => "1"}).remove_member(2) }
    end
  end
end
