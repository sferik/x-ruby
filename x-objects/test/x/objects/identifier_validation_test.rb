# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class IdentifierValidationTest < Minitest::Test
    cover Objects::Utils
    cover Resource
    cover Objects::Finders
    cover Objects::Relationships
    cover Objects::API::Actions::Relationships

    MESSAGE = "\"sferik\" is not an identifier: pass a resource, an Integer, or a String of digits"

    def setup
      @client = FakeClient.new
    end

    def test_an_identifier_of_digits
      assert_equal %w[7505382 7505382 7505382], [7_505_382, "7505382", User.new({"id" => "7505382"})].map { |value| Objects::Utils.id_of(value) }
    end

    def test_a_value_that_is_not_a_number_is_refused
      error = assert_raises(ArgumentError) { Objects::Utils.id_of("sferik") }

      assert_equal MESSAGE, error.message
      assert_raises(ArgumentError) { Objects::Utils.id_of("12a") }
      assert_raises(ArgumentError) { Objects::Utils.id_of("a12") }
      assert_raises(ArgumentError) { Objects::Utils.id_of("") }
    end

    def test_a_raw_identifier_is_taken_as_it_is
      assert_equal "1DXxyRYNejbKM", Objects::Utils.id_of("1DXxyRYNejbKM", raw: true)
    end

    def test_from_id_refuses_a_username
      assert_equal MESSAGE, assert_raises(ArgumentError) { User.from_id("sferik", client: @client) }.message
    end

    def test_from_id_takes_an_identifier_that_is_not_a_number_for_a_resource_whose_identifiers_are_not
      assert_equal "1DXxyRYNejbKM", Space.from_id("1DXxyRYNejbKM").id
    end

    def test_find_takes_an_identifier_that_is_not_a_number_for_a_resource_whose_identifiers_are_not
      @client.stub(:get, "spaces/1DXxyRYNejbKM", {"data" => {"id" => "1DXxyRYNejbKM"}})

      assert_equal "1DXxyRYNejbKM", Space.find("1DXxyRYNejbKM", client: @client).id
    end

    def test_find_all_takes_identifiers_that_are_not_numbers_for_a_resource_whose_identifiers_are_not
      @client.stub(:get, "spaces", ->(query, _) { {"data" => query.fetch("ids").split(",").map { |id| {"id" => id} }} })

      assert_equal %w[1DXxyRYNejbKM 1YpKkgVgevkxj], Space.find_all(%w[1DXxyRYNejbKM 1YpKkgVgevkxj], client: @client).map(&:id)
    end

    def test_find_refuses_an_identifier_that_is_not_a_number
      assert_raises(ArgumentError) { Post.find("sferik", client: @client) }
      assert_raises(ArgumentError) { Post.find_all(["sferik"], client: @client) }
      assert_empty @client.requests
    end

    def test_an_action_refuses_a_username
      @client.stub(:get, "users/me", {"data" => {"id" => "9"}})

      assert_equal MESSAGE, assert_raises(ArgumentError) { @client.follow("sferik") }.message
      assert_equal ["users/me"], @client.paths
    end
  end
end
