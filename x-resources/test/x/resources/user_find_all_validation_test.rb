# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A lookup of users by identifier and username checks every username before it looks anything up
  class UserFindAllValidationTest < Minitest::Test
    cover Resources.const_get(:UserFinders)

    def setup
      @client = FakeClient.new
    end

    def test_find_users_refuses_a_username_among_identifiers_before_looking_the_identifiers_up
      assert_raises(ArgumentError) { User.find_all([1, 2, "bad name"], client: @client) }
      assert_raises(ArgumentError) { @client.find_all_users([1, "sferik", "a?expansions=x"]) }
      assert_empty @client.requests
    end
  end
end
