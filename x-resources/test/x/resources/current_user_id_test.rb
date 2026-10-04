# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class CurrentUserIdTest < Minitest::Test
    cover Resources.const_get(:Lookups)
    cover Resources.const_get(:Utils)
    cover Resources.const_get(:Actions)::Relationships
    cover Resources.const_get(:Actions)::Engagement
    cover Resources.const_get(:Relationships)

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

    # A client whose credentials can be replaced, as those of X::Client are when it is given new ones
    class ReplaceableClient < FakeClient
      attr_accessor :authenticator
    end

    # An X::Client that includes the object layer, and answers each request with the same user, recording its path
    class LookingUpClient < Client
      include Resources::API

      def initialize(paths)
        super(bearer_token: "TOKEN")
        @paths = paths
      end

      def get(endpoint, **)
        @paths << URI(endpoint).path
        {"data" => {"id" => "9"}}
      end
    end

    def test_an_x_client_keeps_the_identifier_in_its_memo
      client = LookingUpClient.new(paths = [])

      assert_equal [9, 9], [client.current_user_id, client.current_user_id]
      assert_equal [["users/me"], 9], [paths, client.memoized(:x_resources_current_user_id)]
      refute client.instance_variable_defined?(:@x_resources_current_user_id)
    end

    def test_a_frozen_x_client_looks_the_user_up_once
      client = LookingUpClient.new(paths = []).freeze
      client.current_user!

      assert_equal [9, ["users/me"]], [client.current_user_id, paths]
    end

    def test_the_identifier_is_kept_apart_from_a_current_user_id_of_the_class_that_includes_the_api
      client = FakeClient.new
      client.instance_variable_set(:@current_user_id, :the_application_user)
      client.stub(:get, "users/me", {"data" => {"id" => "9"}})

      assert_equal 9, client.current_user_id
      assert_equal :the_application_user, client.instance_variable_get(:@current_user_id)
    end

    def test_a_lookup_of_the_user_spares_current_user_id_a_request
      [:current_user, :current_user!].each do |lookup|
        client = FakeClient.new.stub(:get, "users/me", {"data" => {"id" => "9"}})
        client.public_send(lookup)

        assert_equal 9, client.current_user_id
        assert_equal ["users/me"], client.paths
      end
    end

    def test_a_client_given_other_credentials_looks_the_user_up_again
      client = ReplaceableClient.new.stub(:get, "users/me", {"data" => {"id" => "9"}})
      client.authenticator = AnonymousAuthenticator.new("first")
      client.current_user_id
      client.authenticator = AnonymousAuthenticator.new("second")
      client.stub(:get, "users/me", {"data" => {"id" => "10"}})

      assert_equal 10, client.current_user_id
      assert_equal ["users/me", "users/me"], client.paths
    end

    def test_a_frozen_client_looks_the_user_up_each_time
      client = FakeClient.new.stub(:get, "users/me", {"data" => {"id" => "9"}}).freeze

      assert_equal [9, 9], [client.current_user_id, client.current_user_id]
      assert_equal ["users/me", "users/me"], client.paths
    end

    def test_credentials_that_name_a_user_need_no_request
      client = UserClient.new(7_505_382)

      assert_equal 7_505_382, client.current_user_id
      assert_empty client.requests
    end

    def test_credentials_that_name_a_user_by_a_string_of_digits_name_them_by_an_integer
      client = UserClient.new("7505382")
      client.stub(:get, "users/2", {"data" => {"id" => "2", "connection_status" => %w[following]}})

      assert_equal 7_505_382, client.current_user_id
      assert User.from_id(7_505_382, client:).follows?(2)
      assert_equal ["users/2"], client.paths
    end

    def test_credentials_that_name_a_user_by_anything_else_are_refused
      ["7505382-abc", "", 7.5, :id].each do |user_id|
        error = assert_raises(ArgumentError) { UserClient.new(user_id).current_user_id }

        assert_equal "invalid value for Integer(): #{user_id.to_s.inspect}", error.message
      end
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
