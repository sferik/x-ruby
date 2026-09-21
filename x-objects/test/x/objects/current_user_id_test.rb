# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class CurrentUserIdTest < Minitest::Test
    cover Objects::API::Lookups
    cover Objects::Utils
    cover Objects::API::Actions::Relationships
    cover Objects::API::Actions::Engagement
    cover Objects::Relationships

    # An authenticator double that names the user its credentials act for, as an OAuth 1.0a one does
    UserAuthenticator = Struct.new(:user_id)
    # An authenticator double that names no user, as every other authenticator of x-core does
    AnonymousAuthenticator = Struct.new(:access_token)

    class UserClient < FakeClient
      attr_reader :authenticator

      def initialize(user_id)
        super()
        @authenticator = UserAuthenticator.new(user_id)
      end
    end

    # A client of another gem, whose authenticator answers no user at all
    class ForeignClient < FakeClient
      attr_reader :authenticator

      def initialize
        super
        @authenticator = AnonymousAuthenticator.new("7505382-abc")
      end
    end

    def test_credentials_that_name_a_user_need_no_request
      client = UserClient.new(7_505_382)

      assert_equal 7_505_382, client.current_user_id
      assert_empty client.requests
    end

    def test_other_clients_look_the_user_up_once
      [FakeClient.new, ForeignClient.new, UserClient.new(nil)].each do |client|
        client.stub(:get, "users/me", {"data" => {"id" => "9"}})

        assert_equal [9, 9], [client.current_user_id, client.current_user_id]
        assert_equal ["users/me"], client.paths
      end
    end

    def test_actions_use_the_identifier_the_credentials_name
      client = UserClient.new(7_505_382)
      client.stub(:post, "users/7505382/likes", {"data" => {"liked" => true}})
      client.stub(:post, "users/7505382/following", {"data" => {"following" => true}})

      assert client.like(1)
      assert client.follow(2)
      assert_equal ["users/7505382/likes", "users/7505382/following"], client.paths
    end

    def test_follows_compares_the_identifier_the_credentials_name
      client = UserClient.new(7_505_382)
      client.stub(:get, "users/2", {"data" => {"id" => "2", "connection_status" => %w[following]}})

      assert User.from_id(7_505_382, client:).follows?(2)
      assert_equal ["users/2"], client.paths
    end
  end
end
