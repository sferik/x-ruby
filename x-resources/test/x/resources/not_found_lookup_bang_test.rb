# frozen_string_literal: true

require "x/core"
require_relative "../../test_helper"

module X
  # A finder that ends in a bang raises MissingResource for a resource the API answers with a 404 that reports it as
  # not found, as for one it answers with no data, naming what was looked up and the problems of the response, with
  # the NotFound as its cause. Any other 404 raises NotFound, as it does from the client
  class NotFoundLookupBangTest < Minitest::Test
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:UserFinders)
    cover Resources.const_get(:Lookups)
    cover Media

    DETAIL = "Could not find user with username: [nobody]."
    BODY = %({"errors":[{"value":"nobody","detail":"#{DETAIL}","title":"Not Found Error","resource_type":"user","parameter":"username","resource_id":"nobody",) +
      %("type":"https://api.twitter.com/2/problems/resource-not-found"}],"title":"Not Found Error","detail":"#{DETAIL}","type":"https://api.twitter.com/2/problems/resource-not-found"})
    JSON_HEADERS = {"content-type" => "application/json; charset=utf-8"}.freeze
    HTML_HEADERS = {"content-type" => "text/html"}.freeze
    BY_USERNAME = [->(client) { client.find_user!("nobody") }, ->(client) { client.find_user_by_username!("@nobody") }, ->(client) { User.find!("nobody", client:) }].freeze
    BY_ID = [->(client) { client.find_user!(1) }, ->(client) { client.find_user_by_id!("1") }, ->(client) { User.find_by_id!(User.from_id(1), client:) }].freeze
    POSTS = [->(client) { client.find_post!(1) }, ->(client) { client.find_tweet!(1) }, ->(client) { Post.find!(Post.from_id(1), client:) }].freeze

    def setup
      @client = FakeClient.new
    end

    def test_find_bang_of_a_username_the_api_answers_404_for_raises_missing_resource
      @client.stub(:get, "users/by/username/nobody", not_found("users/by/username/nobody"))
      errors = missing(BY_USERNAME)

      assert_equal ["Could not find X::User @nobody: #{DETAIL}"] * 3, errors.map(&:message)
      assert_equal [DETAIL] * 3, errors.flat_map(&:problems).map(&:detail)
      assert_equal [404] * 3, causes(errors).map(&:status)
    end

    def test_find_bang_of_an_identifier_the_api_answers_404_for_names_the_identifier
      body = '{"errors":[{"title":"Not Found Error","detail":"Could not find user with id: [1].","type":"https://api.twitter.com/2/problems/resource-not-found"}]}'
      @client.stub(:get, "users/1", not_found("users/1", body))
      errors = missing(BY_ID)

      assert_equal ["Could not find X::User 1: Could not find user with id: [1]."] * 3, errors.map(&:message)
      assert_equal [NotFound] * 3, causes(errors).map(&:class)
    end

    def test_find_bang_explains_itself_with_the_problem_a_404_describes_itself_as
      @client.stub(:get, "tweets/1", not_found("tweets/1", '{"title":"Not Found Error","type":"https://api.twitter.com/2/problems/resource-not-found"}'))
      errors = missing(POSTS)

      assert_equal ["Could not find X::Post 1: Not Found Error"] * 3, errors.map(&:message)
      assert_equal [NotFound] * 3, causes(errors).map(&:class)
    end

    def test_find_bang_of_media_the_api_answers_404_for_names_the_media_key
      @client.stub(:get, "media/3_1", not_found("media/3_1"))
      error = assert_raises(MissingResource) { @client.find_media!("3_1") }

      assert_equal "Could not find X::Media 3_1: #{DETAIL}", error.message
      assert_instance_of NotFound, error.cause
    end

    def test_find_bang_of_a_bare_404_raises_not_found
      {"users/by/username/nobody" => ["", {}], "users/1" => ["<html>Not Found</html>", HTML_HEADERS], "tweets/1" => ["", {}]}.each { |path, bare| @client.stub(:get, path, not_found(path, *bare)) }
      errors = [BY_USERNAME.first, BY_ID.first, POSTS.first].map { |lookup| assert_raises(NotFound) { lookup.call(@client) } }

      assert_equal ["GET /2/users/by/username/nobody: Not Found", "GET /2/users/1: Not Found", "GET /2/tweets/1: Not Found"], errors.map(&:message)
      assert_equal [nil] * 3, causes(errors)
    end

    def test_find_bang_of_a_200_with_no_data_has_no_cause
      @client.stub(:get, "users/1", {"errors" => [{"title" => "Not Found Error", "detail" => "Could not find user with id: [1]."}]})
      error = assert_raises(MissingResource) { @client.find_user!(1) }

      assert_equal "Could not find X::User 1: Could not find user with id: [1].", error.message
      assert_nil error.cause
    end

    private

    # A response that raises the NotFound x-core raises for a 404 to the lookup of a path with the body, as X::Client does
    def not_found(path, body = BODY, headers = JSON_HEADERS)
      ->(*) { raise NotFound.new(status: 404, headers:, body:, http_method: "GET", uri: URI("https://api.x.com/2/#{path}?user.fields=id")) }
    end

    # The error each MissingResource was raised in the rescue of
    def causes(errors) = errors.map(&:cause)

    # The MissingResource each lookup raises
    def missing(lookups)
      lookups.map { |lookup| assert_raises(MissingResource) { lookup.call(@client) } }
    end
  end
end
