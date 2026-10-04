# frozen_string_literal: true

require "x/core"
require_relative "../../test_helper"

module X
  # A lookup of one resource reads the NotFound of a 404 to it as a resource that is missing only when the body reports
  # a resource as not found. A 404 whose body reports no such problem, such as that of a client pointed at the wrong
  # host or API version, raises as it does from the client, and nothing is remembered of it
  class NotFoundBodyTest < Minitest::Test
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:UserFinders)
    cover Resources.const_get(:Relationships)
    cover Resource

    JSON_HEADERS = {"content-type" => "application/json; charset=utf-8"}.freeze
    HTML_HEADERS = {"content-type" => "text/html"}.freeze
    INVALID = "https://api.twitter.com/2/problems/invalid-request"
    DETAIL = "Could not find user with id: [7]."
    # The bodies of a 404 that report the resource as not found: the problem under each host, among the errors and
    # described by the body itself, among the errors alone, by the body alone, by the body alone though it names
    # errors, and among the errors behind one of another type
    MISSING = %w[https://api.twitter.com/2/problems/resource-not-found https://api.x.com/2/problems/resource-not-found].flat_map do |type|
      [%({"errors":[{"detail":"#{DETAIL}","type":"#{type}"}],"title":"Not Found Error","detail":"#{DETAIL}","type":"#{type}"}),
        %({"errors":[{"detail":"#{DETAIL}","type":"#{type}"}]}),
        %({"title":"Not Found Error","detail":"#{DETAIL}","type":"#{type}"}),
        %({"errors":[{"detail":"#{DETAIL}"}],"title":"Not Found Error","type":"#{type}"}),
        %({"errors":[{"detail":"#{DETAIL}","type":"#{INVALID}"},{"detail":"#{DETAIL}","type":"#{type}"}]})]
    end.freeze
    # The bodies of a 404 that report no resource as not found: none, a page, the error of v1.1, a problem that names
    # no type, errors that name none, a problem of another type, and a problem of no type
    OTHER = [["", {}], ["<html>Not Found</html>", HTML_HEADERS], ['{"errors":[{"message":"Sorry, that page does not exist","code":34}]}', JSON_HEADERS],
      [%({"title":"Not Found Error","detail":"#{DETAIL}"}), JSON_HEADERS], [%({"errors":[{"detail":"#{DETAIL}"}]}), JSON_HEADERS],
      [%({"errors":[{"detail":"#{DETAIL}","type":"#{INVALID}"}],"title":"Invalid Request","type":"#{INVALID}"}), JSON_HEADERS],
      ['{"title":"Not Found","type":"about:blank"}', JSON_HEADERS]].freeze

    def setup
      @client = FakeClient.new.stub(:get, "users/me", {"data" => {"id" => "9"}})
      @problems = []
    end

    def test_find_raises_a_404_that_reports_no_resource_as_not_found
      OTHER.each do |body, headers|
        @client.stub(:get, "users/7", raising("https://api.x.com/1.1/users/7", body, headers))

        assert_equal "/1.1/users/7", assert_raises(NotFound) { @client.find_user(7) { |problem| @problems << problem } }.uri.path
      end
      assert_empty @problems
    end

    def test_find_bang_and_follows_raise_a_404_that_reports_no_resource_as_not_found
      OTHER.each do |body, headers|
        @client.stub(:get, "users/7", raising("https://api.x.com/1.1/users/7", body, headers))

        assert_nil assert_raises(NotFound) { @client.find_user!(7) }.cause
        assert_raises(NotFound) { User.new({"id" => "9"}, client: @client).follows?(7) }
      end
    end

    def test_hydrate_raises_a_404_that_reports_no_resource_as_not_found_and_remembers_nothing_of_it
      OTHER.each do |body, headers|
        @client.stub(:get, "users/7", raising("https://api.x.com/1.1/users/7", body, headers))
        user = User.from_id(7, client: @client)

        assert_raises(NotFound) { user.hydrate }
        @client.stub(:get, "users/7", {"data" => {"id" => "7", "username" => "sferik"}})

        assert_equal "sferik", user.hydrate.username
      end
    end

    def test_a_404_that_reports_the_resource_as_not_found_is_missing
      MISSING.each do |body|
        @client.stub(:get, "users/7", raising("https://api.x.com/2/users/7", body))

        assert_nil @client.find_user(7)
        assert_equal "Could not find X::User 7: #{DETAIL}", assert_raises(MissingResource) { @client.find_user!(7) }.message
        assert_nil User.from_id(7, client: @client).hydrate
        refute User.new({"id" => "9"}, client: @client).follows?(7)
      end
    end

    def test_a_block_is_given_the_problems_a_404_names_when_only_the_body_itself_reports_the_resource_as_not_found
      @client.stub(:get, "users/7", raising("https://api.x.com/2/users/7", MISSING.fetch(3)))

      assert_nil(@client.find_user(7) { |problem| @problems << problem })
      assert_equal [{"detail" => DETAIL}], @problems.map(&:to_h)
      assert_equal @problems, assert_raises(MissingResource) { @client.find_user!(7) }.problems
    end

    def test_a_lookup_through_a_base_url_with_a_path_before_the_endpoint_is_missing
      @client.stub(:get, "users/7", raising("https://gateway.example/x/2/users/7?user.fields=id%2Cname"))

      assert_nil @client.find_user(7)
      assert_equal "/x/2/users/7", assert_raises(MissingResource) { @client.find_user!(7) }.cause.uri.path
    end

    def test_a_lookup_of_a_username_through_a_base_url_with_a_path_before_the_endpoint_is_missing
      @client.stub(:get, "users/by/username/nobody", raising("https://gateway.example/x/2/users/by/username/nobody"))

      assert_nil @client.find_user("nobody")
      assert_equal "Could not find X::User @nobody: #{DETAIL}", assert_raises(MissingResource) { @client.find_user_by_username!("@nobody") }.message
    end

    private

    # A response that raises the NotFound x-core raises for a 404 to the GET of a URI, as X::Client builds it
    def raising(uri, body = MISSING.first, headers = JSON_HEADERS)
      ->(*) { raise NotFound.new(status: 404, headers:, body:, http_method: "GET", uri: URI(uri)) }
    end
  end
end
