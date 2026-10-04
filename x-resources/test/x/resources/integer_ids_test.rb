# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class IntegerIdsTest < Minitest::Test
    cover Resources.const_get(:Attributes)
    cover Resources.const_get(:Utils)
    cover Resources.const_get(:Shape)
    cover Resource
    cover Resources.const_get(:Finders)
    cover Resources.const_get(:BatchFinders)
    cover Place
    cover Space
    cover Media

    def test_id_types
      assert_equal %i[integer integer integer integer integer integer], [User, Post, List, DirectMessage, Community, Poll].map { |klass| klass.__send__(:id_type) }
      assert_equal %i[raw raw media_key], [Space, Place, Media].map { |klass| klass.__send__(:id_type) }
    end

    def test_numeric_identifiers_are_integers
      assert_equal 1_346_889_436_626_259_968, Post.new({"id" => "1346889436626259968"}).id
      assert_equal 7_505_382, User.new({"id" => "7505382"}).id
    end

    def test_identifiers_that_are_not_numbers_stay_strings
      assert_equal "1DXxyRYNejbKM", Space.new({"id" => "1DXxyRYNejbKM"}).id
      assert_equal "f29bbd03562e37d3", Place.new({"id" => "f29bbd03562e37d3"}).id
      assert_equal "3_1", Media.new({"media_key" => "3_1"}).id
    end

    def test_a_missing_identifier_is_nil_and_a_missing_list_of_them_empty
      assert_nil Post.new({"id" => "1"}).author_id
      assert_empty Space.new({"id" => "a"}).host_ids
    end

    def test_integer_reads_decimal_digits
      assert_equal 10, Resources.const_get(:Shape).integer("010")
      assert_equal 7, Resources.const_get(:Shape).integer(7)
      assert_nil Resources.const_get(:Shape).integer(nil)
      assert_raises(ArgumentError) { Resources.const_get(:Shape).integer("sferik") }
    end

    def test_integer_reads_neither_a_sign_an_underscore_whitespace_nor_a_negative_integer
      ["-3", "+3", "1_000", " 12", "12\n", -3, 3.0, :"3"].each do |value|
        error = assert_raises(ArgumentError, value.inspect) { Resources.const_get(:Shape).integer(value) }

        assert_equal "invalid value for Integer(): #{value.to_s.inspect}", error.message
      end
    end

    def test_an_identifier_of_a_resource_referred_to_is_read_as_strictly_as_that_resource_is_found
      post = Post.new({"id" => "1", "author_id" => "-3", "edit_history_tweet_ids" => ["1", "+2"]})

      assert_equal "X::Post#author_id cannot be read from \"-3\"", assert_raises(InvalidAttribute) { post.author_id }.message
      assert_raises(InvalidAttribute) { post.edit_history_post_ids }
    end
  end
end
