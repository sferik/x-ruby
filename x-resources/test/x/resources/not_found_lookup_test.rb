# frozen_string_literal: true

require "x/core"
require_relative "../../test_helper"

module X
  # X documents both a 200 with no data and a 404 that reports the resource as not found as its answer to the lookup
  # of one resource that is not there, so the lookup of one reads the NotFound of such a 404 as it reads a response
  # that holds no data: it finds nothing. Any other 404 raises NotFound, as it does from the client
  class NotFoundLookupTest < Minitest::Test
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:UserFinders)
    cover Resources.const_get(:Lookups)
    cover Media

    DETAIL = "Could not find user with username: [nobody]."
    BODY = '{"errors":[{"value":"nobody","detail":"Could not find user with username: [nobody].","title":"Not Found Error",' \
      '"resource_type":"user","parameter":"username","resource_id":"nobody","type":"https://api.twitter.com/2/problems/resource-not-found"}],' \
      '"title":"Not Found Error","detail":"Could not find user with username: [nobody].","type":"https://api.twitter.com/2/problems/resource-not-found"}'
    JSON_HEADERS = {"content-type" => "application/json; charset=utf-8"}.freeze
    HTML_HEADERS = {"content-type" => "text/html"}.freeze
    # Each finder of the client, with the path it requests
    FINDERS = [[:find_user, "nobody", "users/by/username/nobody"], [:find_user_by_username, "@nobody", "users/by/username/nobody"], [:find_user, 1, "users/1"],
      [:find_user_by_id, "1", "users/1"], [:find_post, 1, "tweets/1"], [:find_tweet, 1, "tweets/1"], [:find_list, 1, "lists/1"], [:find_space, "1", "spaces/1"],
      [:find_media, "3_1", "media/3_1"], [:find_community, 1, "communities/1"], [:find_direct_message, 1, "dm_events/1"]].freeze

    def setup
      @client = FakeClient.new
      @problems = []
    end

    def test_find_of_a_resource_the_api_answers_404_for_is_nil
      FINDERS.each { |_, _, path| @client.stub(:get, path, not_found(path)) }

      assert_equal [nil] * FINDERS.size, FINDERS.map { |finder, value, _| @client.public_send(finder, value) }
      assert_equal FINDERS.map(&:last), @client.paths
    end

    def test_find_of_a_resource_answered_with_a_bare_404_raises_not_found
      @client.stub(:get, "users/by/username/nobody", not_found("users/by/username/nobody", "", {}))
      @client.stub(:get, "tweets/1", not_found("tweets/1", "<html>Not Found</html>", HTML_HEADERS))

      assert_equal "GET /2/users/by/username/nobody: Not Found", assert_raises(NotFound) { User.find("nobody", client: @client) }.message
      assert_equal "GET /2/tweets/1: Not Found", assert_raises(NotFound) { Post.find(1, client: @client) }.message
    end

    def test_a_block_is_given_the_problems_of_a_404_as_it_is_those_of_a_200
      @client.stub(:get, "users/by/username/nobody", not_found("users/by/username/nobody"))
      @client.stub(:get, "users/1", not_found("users/1"))

      assert_nil(@client.find_user("nobody") { |problem| @problems << problem })
      assert_nil(User.find_by_id(1, client: @client) { |problem| @problems << problem })
      assert_equal [DETAIL, DETAIL], @problems.map(&:detail)
      assert_equal %w[nobody nobody], @problems.map(&:resource_id)
    end

    def test_a_block_is_given_the_problem_a_404_describes_itself_as_when_it_names_no_errors
      body = '{"title":"Not Found Error","detail":"Could not find tweet with id: [1].","type":"https://api.twitter.com/2/problems/resource-not-found"}'
      @client.stub(:get, "tweets/1", not_found("tweets/1", body))

      assert_nil(Post.find(1, client: @client) { |problem| @problems << problem })
      assert_equal ["Could not find tweet with id: [1]."], @problems.map(&:detail)
    end

    def test_a_block_is_given_nothing_of_a_bare_404
      @client.stub(:get, "users/by/username/nobody", not_found("users/by/username/nobody", "", {}))
      @client.stub(:get, "users/1", not_found("users/1", "<html>Not Found</html>", HTML_HEADERS))

      assert_raises(NotFound) { User.find("nobody", client: @client) { |problem| @problems << problem } }
      assert_raises(NotFound) { User.find(1, client: @client) { |problem| @problems << problem } }
      assert_empty @problems
    end

    def test_any_other_status_of_a_lookup_raises_as_it_is
      [[Forbidden, 403], [Unauthorized, 401], [TooManyRequests, 429], [ServiceUnavailable, 503]].each do |error, status|
        FINDERS.each { |_, _, path| @client.stub(:get, path, ->(*) { raise error.new(status:, headers: JSON_HEADERS, body: BODY) }) }

        FINDERS.each { |finder, value, _| assert_raises(error) { @client.public_send(finder, value) } }
        FINDERS.each { |finder, value, _| assert_raises(error) { @client.public_send(:"#{finder}!", value) } }
      end
    end

    def test_a_404_to_the_authenticated_user_whose_path_names_no_user_raises_not_found
      @client.stub(:get, "users/me", not_found("users/me"))

      assert_raises(NotFound) { @client.current_user }
      assert_raises(NotFound) { @client.current_user! }
      assert_raises(NotFound) { User.current(client: @client) }
    end

    def test_a_404_to_a_lookup_of_several_raises_not_found
      @client.stub(:get, "users", not_found("users"))
      @client.stub(:get, "users/by", not_found("users/by"))

      assert_raises(NotFound) { @client.find_all_users([1, 2]) }
      assert_raises(NotFound) { User.find_all_by_username(%w[nobody], client: @client) }
    end

    private

    # A response that raises the NotFound x-core raises for a 404 to the lookup of a path with the body, as X::Client does
    def not_found(path, body = BODY, headers = JSON_HEADERS)
      ->(*) { raise NotFound.new(status: 404, headers:, body:, http_method: "GET", uri: URI("https://api.x.com/2/#{path}?user.fields=id")) }
    end
  end
end
