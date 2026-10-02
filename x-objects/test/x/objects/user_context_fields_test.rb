# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The fields of a user that depend on who is authenticated, which a lookup asks for only when user.fields names them,
  # read nil when the response holds none
  class UserContextFieldsTest < Minitest::Test
    cover User

    def test_the_fields_a_response_holds
      user = User.new({"id" => "5", "receives_your_dm" => true, "subscribes_to_you" => false, "subscription" => {"subscribes_to_you" => true}})

      assert_equal [true, true, false, false], [user.receives_your_dm, user.receives_your_dm?, user.subscribes_to_you, user.subscribes_to_you?]
      assert_equal({"subscribes_to_you" => true}, user.subscription)
    end

    def test_the_fields_a_response_left_out
      user = User.new({"id" => "5"})

      assert_equal [nil, false, nil, false, nil], [user.receives_your_dm, user.receives_your_dm?, user.subscribes_to_you, user.subscribes_to_you?, user.subscription]
    end

    def test_a_lookup_that_names_them_reads_them
      client = FakeClient.new.stub(:get, "users/5", {"data" => {"id" => "5", "receives_your_dm" => false, "subscribes_to_you" => true}})
      user = client.find_user(5, "user.fields": "receives_your_dm,subscribes_to_you")

      assert_equal [false, true], [user.receives_your_dm, user.subscribes_to_you?]
      assert_equal "receives_your_dm,subscribes_to_you", client.queries.first["user.fields"]
      refute_predicate user, :hydrated?
    end

    def test_a_value_that_is_not_one_raises
      assert_raises(InvalidAttribute) { User.new({"id" => "5", "receives_your_dm" => "yes"}).receives_your_dm }
      assert_raises(InvalidAttribute) { User.new({"id" => "5", "subscribes_to_you" => 1}).subscribes_to_you? }
    end

    def test_pattern_matching_reads_them
      user = User.new({"id" => "5", "receives_your_dm" => true})

      assert_equal({receives_your_dm: true, subscribes_to_you: nil, subscription: nil}, user.deconstruct_keys(%i[receives_your_dm subscribes_to_you subscription]))
    end
  end
end
