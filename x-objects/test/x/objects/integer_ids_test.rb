require_relative "../../test_helper"

module X
  class IntegerIdsTest < Minitest::Test
    cover Objects::Attributes
    cover Objects::Utils
    cover Objects::Resource
    cover Objects::Finders
    cover Place
    cover Space
    cover Media

    def test_id_types
      assert_equal %i[integer integer integer integer integer integer], [User, Post, List, DirectMessage, Community, Poll].map(&:id_type)
      assert_equal %i[raw raw raw], [Space, Place, Media].map(&:id_type)
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

    def test_missing_identifiers_are_nil
      assert_nil Post.new({"id" => "1"}).author_id
      assert_nil Space.new({"id" => "a"}).host_ids
    end

    def test_integer_reads_decimal_digits
      assert_equal 10, Objects::Utils.integer("010")
      assert_equal 7, Objects::Utils.integer(7)
      assert_nil Objects::Utils.integer(nil)
      assert_raises(ArgumentError) { Objects::Utils.integer("sferik") }
    end
  end
end
