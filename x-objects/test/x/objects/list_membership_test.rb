require_relative "../../test_helper"

module X
  class ListMembershipTest < Minitest::Test
    cover List

    def setup
      @client = FakeClient.new
      @client.stub(:get, "lists/9/members", {"data" => [{"id" => "2"}]})
      @client.stub(:get, "users/2/list_memberships", {"data" => [{"id" => "8"}, {"id" => "9"}]})
      @client.stub(:get, "users/2", {"data" => {"id" => "2", "public_metrics" => {"listed_count" => 2}}})
      @client.stub(:get, "users/3", {"data" => {"id" => "3", "public_metrics" => {"listed_count" => 5000}}})
      @client.stub(:get, "users/4", {"errors" => []})
    end

    def test_a_private_list_scans_its_members
      assert_operator list(private: true), :member?, 2
      assert_equal ["lists/9/members"], @client.paths
    end

    def test_a_public_list_scans_the_fewer_memberships_of_the_user
      assert_operator list, :member?, 2
      assert_equal ["users/2", "users/2/list_memberships"], @client.paths
      assert_equal({"max_results" => "100", "list.fields" => "id"}, @client.queries.last)
    end

    def test_memberships_that_do_not_include_the_list
      @client.stub(:get, "users/2/list_memberships", {"data" => [{"id" => "8"}]})

      refute_operator list, :member?, 2
    end

    def test_a_public_list_scans_its_fewer_members
      refute_operator list, :member?, 3
      assert_equal ["users/3", "lists/9/members"], @client.paths
    end

    def test_as_many_memberships_as_members_scans_the_members
      assert_operator list(member_count: 2), :member?, 2
      assert_equal ["users/2", "lists/9/members"], @client.paths
    end

    def test_a_hydrated_user_needs_no_lookup
      user = User.new({"id" => "2", "public_metrics" => {"listed_count" => 2}}, client: @client, hydrated: true)

      assert_operator list, :member?, user
      assert_equal ["users/2/list_memberships"], @client.paths
    end

    def test_a_hydrated_user_of_a_subclass_needs_no_lookup
      user = Class.new(User).new({"id" => "2", "public_metrics" => {"listed_count" => 2}}, client: @client, hydrated: true)

      assert_operator list, :member?, user
      assert_equal ["users/2/list_memberships"], @client.paths
    end

    def test_a_user_stub_is_looked_up_by_identifier
      assert_operator list, :member?, User.new({"id" => "2"})
      assert_operator list, :member?, "2"
      assert_equal ["users/2", "users/2/list_memberships"] * 2, @client.paths
    end

    def test_a_missing_user_scans_the_members
      refute_operator list, :member?, 4
      assert_equal ["users/4", "lists/9/members"], @client.paths
    end

    def test_a_list_stub_is_looked_up_first
      @client.stub(:get, "lists/9", {"data" => {"id" => "9", "private" => false, "member_count" => 1000}})

      assert_operator List.new({"id" => "9"}, client: @client), :member?, 2
      assert_equal ["lists/9", "users/2", "users/2/list_memberships"], @client.paths
    end

    def test_a_list_stub_that_turns_out_private_scans_its_members
      @client.stub(:get, "lists/9", {"data" => {"id" => "9", "private" => true, "member_count" => 1000}})

      assert_operator List.new({"id" => "9"}, client: @client), :member?, 2
      assert_equal ["lists/9", "lists/9/members"], @client.paths
    end

    def test_a_missing_list_or_member_count_scans_the_members
      @client.stub(:get, "lists/9", {"errors" => []})

      assert_operator List.new({"id" => "9"}, client: @client), :member?, 2
      assert_operator List.new({"id" => "9", "private" => false}, client: @client, hydrated: true), :member?, 2
      assert_equal ["lists/9", "lists/9/members", "lists/9/members"], @client.paths
    end

    private

    def list(private: false, member_count: 1000)
      List.new({"id" => "9", "private" => private, "member_count" => member_count}, client: @client, hydrated: true)
    end
  end
end
