# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class CurrentUserIdTest < Minitest::Test
    cover Objects::API::Lookups
    cover Objects::Utils
    cover Objects::API::Actions::Relationships
    cover Objects::API::Actions::Engagement
    cover Objects::Relationships

    # An authenticator double that holds OAuth 1.0a tokens, as a client's does
    TokenAuthenticator = Struct.new(:access_token, :access_token_secret)
    # An authenticator double that holds an access token of no OAuth 1.0a set, as an OAuth 2.0 one does
    BearerAuthenticator = Struct.new(:access_token)

    class TokenClient < FakeClient
      attr_reader :authenticator

      def initialize(access_token:, access_token_secret:)
        super()
        @authenticator = TokenAuthenticator.new(access_token, access_token_secret)
      end
    end

    class BearerClient < FakeClient
      attr_reader :authenticator

      def initialize(access_token)
        super()
        @authenticator = BearerAuthenticator.new(access_token)
      end
    end

    def test_an_oauth1_token_names_the_user_without_a_request
      client = TokenClient.new(access_token: "7505382-abc", access_token_secret: "secret")

      assert_equal 7_505_382, client.current_user_id
      assert_empty client.requests
    end

    def test_other_clients_look_the_user_up_once
      [FakeClient.new, BearerClient.new("7505382-abc"), TokenClient.new(access_token: "7505382-abc", access_token_secret: nil),
        TokenClient.new(access_token: "abc-7505382", access_token_secret: "secret"), TokenClient.new(access_token: nil, access_token_secret: "secret")].each do |client|
        client.stub(:get, "users/me", {"data" => {"id" => "9"}})

        assert_equal [9, 9], [client.current_user_id, client.current_user_id]
        assert_equal ["users/me"], client.paths
      end
    end

    def test_a_token_prefix_is_read_as_decimal_digits
      assert_equal 10, TokenClient.new(access_token: "010-abc", access_token_secret: "secret").current_user_id
    end

    def test_actions_use_the_identifier_from_the_token
      client = TokenClient.new(access_token: "7505382-abc", access_token_secret: "secret")
      client.stub(:post, "users/7505382/likes", {"data" => {"liked" => true}})
      client.stub(:post, "users/7505382/following", {"data" => {"following" => true}})

      assert client.like(1)
      assert client.follow(2)
      assert_equal ["users/7505382/likes", "users/7505382/following"], client.paths
    end

    def test_follows_compares_the_identifier_from_the_token
      client = TokenClient.new(access_token: "7505382-abc", access_token_secret: "secret")
      client.stub(:get, "users/2", {"data" => {"id" => "2", "connection_status" => %w[following]}})

      assert User.from_id(7_505_382, client:).follows?(2)
      assert_equal ["users/2"], client.paths
    end
  end
end
