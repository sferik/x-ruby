# frozen_string_literal: true

require "net/http"
require_relative "../../test_helper"
require "x/core/errors/network_error"
require "x/core/errors/service_unavailable"
require "x/core/errors/too_many_requests"

module X
  class FollowsConnectionStatusTest < Minitest::Test
    cover Objects::Relationships

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      @client.stub(:get, "users/5", {"data" => {"id" => "5", "connection_status" => %w[following followed_by]}})
      @client.stub(:get, "users/6", {"data" => {"id" => "6", "connection_status" => %w[muting]}})
      @client.stub(:get, "users/7", {"errors" => []})
      @me = User.new({"id" => "9"}, client: @client)
    end

    def test_the_authenticated_user_follows_in_one_lookup
      assert @me.follows?(5)
      assert_equal ["users/me", "users/5"], @client.paths
      assert_equal({"user.fields" => "connection_status"}, @client.queries.last)
    end

    def test_a_user_follows_the_authenticated_user_in_one_lookup
      assert User.new({"id" => "5"}, client: @client).follows?(@me)
      refute User.new({"id" => "6"}, client: @client).follows?(9)
      assert_equal ["users/me", "users/5", "users/6"], @client.paths
    end

    def test_connection_status_without_the_relationship
      refute @me.follows?(6)
      refute @me.follows?(User.new({"id" => "7"}))
    end

    def test_a_client_without_a_current_user_scans
      @client.stub(:get, "users/9/following", {"data" => [{"id" => "5"}]})
      plain = Class.new do
        def initialize(fake) = @fake = fake
        def get(...) = @fake.get(...)
      end.new(@client)

      assert User.new({"id" => "9"}, client: plain).follows?(5)
      assert_equal ["users/9/following"], @client.paths
    end

    def test_an_app_only_client_that_cannot_read_the_authenticated_user_scans
      @client.stub(:get, "users/5/following", {"data" => [{"id" => "6"}]})
      [[Forbidden, Net::HTTPForbidden, "403"], [Unauthorized, Net::HTTPUnauthorized, "401"]].each do |error, response, code|
        @client.stub(:get, "users/me", ->(*) { raise error.new(http_response: response.new("1.1", code, "")) })

        assert User.new({"id" => "5"}, client: @client).follows?(6), "scans after #{error}"
      end
      assert_equal ["users/me", "users/5/following"] * 2, @client.paths
    end

    def test_any_other_failure_to_read_the_authenticated_user_ends_the_check_rather_than_scan
      [ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "")),
        TooManyRequests.new(http_response: Net::HTTPTooManyRequests.new("1.1", "429", "")),
        NetworkError.new("Network error: connection reset"), MissingResource.new("Could not find the user")].each do |failure|
        @client.stub(:get, "users/me", ->(*) { raise failure })

        assert_raises(failure.class) { User.new({"id" => "5"}, client: @client).follows?(6) }
      end
      refute_includes @client.paths, "users/5/following"
    end

    def test_an_error_that_is_no_x_error_ends_the_check
      @client.stub(:get, "users/me", ->(*) { raise IOError, "closed" })

      assert_raises(IOError) { User.new({"id" => "5"}, client: @client).follows?(6) }
    end

    def test_connection_status_attribute
      assert_equal %w[following followed_by], User.new({"id" => "5", "connection_status" => %w[following followed_by]}).connection_status
      assert_nil User.new({"id" => "5"}).connection_status
    end
  end
end
