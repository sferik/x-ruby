# frozen_string_literal: true

require "x/core"
require_relative "../../test_helper"

module X
  # A lookup of one resource reads a NotFound as a resource that is missing only when it answers the lookup itself, a
  # GET of the URL of the lookup. A 404 to another request the client made for the lookup, such as the request for a
  # token, raises as it does from the client, and nothing is remembered of it
  class NotFoundOtherRequestTest < Minitest::Test
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:UserFinders)
    cover Resources.const_get(:Relationships)
    cover Resource
    cover Space

    # A client with an app-only client, as an X::Client that signs with OAuth 1.0a has
    class UserClient < FakeClient
      attr_reader :app

      def initialize
        super
        @app = FakeClient.new
      end

      def app_only = app
    end

    JSON_HEADERS = {"content-type" => "application/json; charset=utf-8"}.freeze
    DETAIL = "Could not find user with id: [7]."
    TYPE = "https://api.twitter.com/2/problems/resource-not-found"
    BODY = %({"errors":[{"detail":"#{DETAIL}","type":"#{TYPE}"}],"title":"Not Found Error","detail":"#{DETAIL}","type":"#{TYPE}"})
    TOKEN = ["POST", "https://gateway.example/x/oauth2/token"].freeze
    PATHS = %w[users/7 users/by/username/nobody tweets/7].freeze
    FIND = [->(client) { client.find_user(7) }, ->(client) { User.find_by_id(7, client:) }, ->(client) { client.find_user("nobody") }, ->(client) { Post.find(7, client:) }].freeze
    FIND_BANG = [->(client) { client.find_user!(7) }, ->(client) { User.find_by_id!(7, client:) }, ->(client) { client.find_user!("nobody") }, ->(client) { Post.find!(7, client:) }].freeze
    # The requests a 404 names that are not a GET of users/7, though each but the first two holds its path
    OTHER_REQUESTS = [["POST", "https://api.x.com/2/users/7"], [nil, "https://api.x.com/2/users/7"], ["GET", nil], [nil, nil], ["GET", "https://api.x.com/2/superusers/7"],
      ["GET", "https://api.x.com/2/users/7/tweets"], ["GET", "https://api.x.com/2/users/77"], ["GET", "https://api.x.com/users/7/2"]].freeze

    def setup
      @client = FakeClient.new
      @problems = []
    end

    def test_a_404_to_the_request_for_a_token_is_raised_by_find
      PATHS.each { |path| @client.stub(:get, path, raising(*TOKEN)) }
      errors = FIND.map { |lookup| assert_raises(NotFound) { lookup.call(@client) } }

      assert_equal ["POST /x/oauth2/token: #{DETAIL}"] * 4, errors.map(&:message)
    end

    def test_a_404_to_the_request_for_a_token_is_raised_by_find_bang
      PATHS.each { |path| @client.stub(:get, path, raising(*TOKEN)) }
      errors = FIND_BANG.map { |lookup| assert_raises(NotFound) { lookup.call(@client) } }

      assert_equal ["POST /x/oauth2/token: #{DETAIL}"] * 4, errors.map(&:message)
      assert_equal [nil] * 4, errors.map(&:cause)
    end

    def test_a_block_is_given_nothing_of_a_404_to_the_request_for_a_token
      @client.stub(:get, "users/7", raising(*TOKEN))

      assert_raises(NotFound) { @client.find_user(7) { |problem| @problems << problem } }
      assert_empty @problems
    end

    def test_a_404_to_the_request_for_a_token_is_raised_by_hydrate_which_remembers_nothing_of_it
      @client.stub(:get, "users/7", raising(*TOKEN))
      user = User.from_id(7, client: @client)

      assert_raises(NotFound) { user.hydrate }
      assert_raises(NotFound) { user.refresh }
      @client.stub(:get, "users/7", {"data" => {"id" => "7", "username" => "sferik"}})

      assert_equal "sferik", user.hydrate.username
      assert_equal %w[users/7 users/7 users/7], @client.paths
    end

    def test_a_404_to_the_request_for_a_token_is_raised_by_follows
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})
      @client.stub(:get, "users/7", raising(*TOKEN))

      assert_raises(NotFound) { User.new({"id" => "9"}, client: @client).follows?(7) }
      assert_raises(NotFound) { User.new({"id" => "7"}, client: @client).follows?(9) }
    end

    def test_a_404_that_does_not_name_a_get_of_the_path_of_the_lookup_is_raised
      OTHER_REQUESTS.each do |http_method, uri|
        @client.stub(:get, "users/7", raising(http_method, uri))

        assert_raises(NotFound) { @client.find_user(7) }
        assert_raises(NotFound) { @client.find_user!(7) }
      end
    end

    def test_a_lookup_of_a_space_reads_the_404_of_the_app_only_client
      client = UserClient.new
      client.app.stub(:get, "spaces/1DXxyRYNejbKM", raising("GET", "https://api.x.com/2/spaces/1DXxyRYNejbKM"))

      assert_nil client.find_space("1DXxyRYNejbKM")
      assert_instance_of NotFound, assert_raises(MissingResource) { client.find_space!("1DXxyRYNejbKM") }.cause
      assert_nil Space.from_id("1DXxyRYNejbKM", client:).hydrate
      assert_empty client.requests
    end

    def test_a_lookup_of_a_space_raises_the_404_the_app_only_client_met_for_its_token
      client = UserClient.new
      client.app.stub(:get, "spaces/1DXxyRYNejbKM", raising("POST", "https://api.x.com/oauth2/token"))

      assert_raises(NotFound) { client.find_space("1DXxyRYNejbKM") }
      assert_raises(NotFound) { client.find_space!("1DXxyRYNejbKM") }
      assert_raises(NotFound) { Space.from_id("1DXxyRYNejbKM", client:).hydrate }
    end

    private

    # A response that raises the NotFound x-core raises for a 404 to a request, with the method and URI of the request
    # it answers, as X::Client builds it
    def raising(http_method, uri)
      ->(*) { raise NotFound.new(status: 404, headers: JSON_HEADERS, body: BODY, http_method:, uri: uri && URI(uri)) }
    end
  end
end
