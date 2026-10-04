# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class IdentifierValidationTest < Minitest::Test
    cover Resources.const_get(:Utils)
    cover Resource
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:BatchFinders)
    cover Resources.const_get(:Relationships)
    cover Resources.const_get(:Actions)::Relationships

    MESSAGE = "\"sferik\" is not an identifier: pass X::User, an Integer, or a String of digits"

    def setup
      @client = FakeClient.new
    end

    def test_an_identifier_of_digits
      assert_equal %w[7505382 7505382 7505382], [7_505_382, "7505382", User.new({"id" => "7505382"})].map { |value| Resources.const_get(:Utils).id_of(value, User) }
    end

    def test_a_value_that_is_not_a_number_is_refused
      error = assert_raises(ArgumentError) { Resources.const_get(:Utils).id_of("sferik", User) }

      assert_equal MESSAGE, error.message
      assert_raises(ArgumentError) { Resources.const_get(:Utils).id_of("12a", User) }
      assert_raises(ArgumentError) { Resources.const_get(:Utils).id_of("a12", User) }
      assert_raises(ArgumentError) { Resources.const_get(:Utils).id_of("", User) }
    end

    def test_a_raw_identifier_is_taken_as_it_is
      assert_equal "1DXxyRYNejbKM", Resources.const_get(:Utils).id_of("1DXxyRYNejbKM", Space)
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

    def test_a_one_to_one_conversation_identifier_is_not_the_identifier_of_a_space_or_a_place
      [Space, Place].each do |klass|
        assert_equal "\"1-2\" is not an identifier: pass #{klass}, or a String of word characters", assert_raises(ArgumentError) { Resources.const_get(:Utils).id_of("1-2", klass) }.message
        assert_raises(ArgumentError) { klass.new({"id" => "1-2"}) }
      end
      assert_raises(ArgumentError) { @client.find_space("1-2") }
      assert_empty @client.requests
    end
  end
end
