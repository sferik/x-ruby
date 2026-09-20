# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class NarrowedHydrationTest < Minitest::Test
    cover Objects::Finders
    cover Objects::Resource

    def setup
      @client = FakeClient.new
      @client.stub(:get, "users/1", lambda { |query, _|
        {"data" => {"id" => "1", "name" => "Erik"}.merge(query["user.fields"].eql?("name") ? {} : {"description" => "Rubyist"})}
      })
      @client.stub(:get, "users", {"data" => [{"id" => "1", "name" => "Erik"}]})
    end

    def test_a_lookup_with_the_default_parameters_is_hydrated
      user = User.find(1, client: @client)

      assert_predicate user, :hydrated?
      assert_same user, user.hydrate
    end

    def test_a_lookup_with_other_fields_hydrates_to_the_full_resource
      user = User.find(1, client: @client, "user.fields": "name")

      refute_predicate user, :hydrated?
      assert_nil user.description
      assert_equal "Rubyist", user.hydrate.description
      assert_equal ["name", User::FIELDS.join(",")], @client.queries.map { |query| query["user.fields"] }
    end

    def test_a_lookup_that_overrides_one_default_parameter_is_not_hydrated
      refute_predicate User.find(1, client: @client, expansions: nil), :hydrated?
      refute_predicate User.find(1, client: @client, "post.fields": "id"), :hydrated?
    end

    def test_a_lookup_given_a_default_parameter_as_it_is_stays_hydrated
      assert_predicate User.find(1, client: @client, "user.fields": User::FIELDS), :hydrated?
      assert_predicate User.find(1, client: @client, "user.fields": User::FIELDS.join(",")), :hydrated?
    end

    def test_a_lookup_with_a_parameter_that_is_no_default_stays_hydrated
      assert_predicate User.find(1, client: @client, "media.fields": "url"), :hydrated?
    end

    def test_a_batch_lookup_with_other_fields_is_not_hydrated
      refute_predicate User.find_all([1], client: @client, "user.fields": "name").first, :hydrated?
      assert_predicate User.find_all([1], client: @client).first, :hydrated?
    end

    def test_a_batch_lookup_sends_the_identifiers_with_the_parameters
      User.find_all([1, 2], client: @client, "user.fields": "name")

      assert_equal({"ids" => "1,2", "user.fields" => "name"}, @client.queries.first.slice("ids", "user.fields"))
    end

    def test_a_lookup_of_many_from_an_endpoint_with_other_fields_is_not_hydrated
      refute_predicate User.lookup_all("users", client: @client, "user.fields": "name").first, :hydrated?
      assert_predicate User.lookup_all("users", client: @client).first, :hydrated?
    end

    def test_a_resource_without_default_parameters_is_fully_requested_by_any_request
      assert Poll.fully_requested_by?({"poll.fields" => "id"})
    end
  end
end
