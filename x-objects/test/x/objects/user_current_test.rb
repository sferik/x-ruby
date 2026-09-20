# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UserCurrentTest < Minitest::Test
    cover User
    cover X::Objects::UserFinders

    def setup
      @client = FakeClient.new
    end

    def test_current_bang
      @client.stub(:get, "users/me", {"data" => {"id" => "1", "username" => "sferik"}})

      assert_equal "sferik", User.current!(client: @client, "user.fields": "id").username
      assert_equal "id", @client.queries.first["user.fields"]
    end

    def test_current_bang_raises_when_the_api_returns_no_user
      @client.stub(:get, "users/me", {"errors" => [{"title" => "Forbidden", "detail" => "Your client app is not configured with the appropriate oauth1 app permissions for this endpoint."}]})
      error = assert_raises(Objects::MissingResource) { User.current!(client: @client) }

      assert_equal "users/me returned no user: Your client app is not configured with the appropriate oauth1 app permissions for this endpoint.", error.message
      assert_equal ["Forbidden"], error.problems.map(&:title)
    end
  end
end
