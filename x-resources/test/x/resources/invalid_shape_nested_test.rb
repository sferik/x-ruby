# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The readers of an object the API nests in a resource, or of a list of them, return a Hash or an Array of them, and
  # raise InvalidAttribute for a response that holds anything else
  class InvalidShapeNestedTest < Minitest::Test
    cover Resources.const_get(:Attributes)
    cover Resources.const_get(:Shape)

    OBJECTS = {
      Post => %i[edit_controls scopes article article_title attachments geo withheld note_post public_metrics],
      User => %i[affiliation subscription entities withheld public_metrics],
      Media => %i[public_metrics],
      Place => %i[geo],
      DirectMessage => %i[attachments entities]
    }.freeze
    LISTS = {
      Post => %i[media_metadata context_annotations referenced_posts],
      Media => %i[variants],
      Poll => %i[options],
      DirectMessage => %i[referenced_posts]
    }.freeze

    def test_an_object_reads_as_the_hash_the_response_holds
      each_reader(OBJECTS) do |klass, name|
        resource = build(klass, name, {"key" => "value"})

        assert_equal({"key" => "value"}, resource.public_send(name))
        assert_predicate resource.public_send(name), :frozen?
        assert_nil build(klass, :other, 1).public_send(name)
      end
    end

    def test_an_object_that_is_not_one_raises
      each_reader(OBJECTS) do |klass, name|
        ["many", [1], 1].each do |value|
          error = assert_raises(InvalidAttribute) { build(klass, name, value).public_send(name) }

          assert_equal "#{klass}##{name} cannot be read from #{value.inspect}", error.message
          assert_equal "#{value.inspect} is not an object", error.cause.message
        end
      end
    end

    def test_a_list_of_objects_reads_as_the_list_the_response_holds
      each_reader(LISTS) do |klass, name|
        resource = build(klass, name, [{"key" => "value"}])

        assert_equal [{"key" => "value"}], resource.public_send(name)
        assert_predicate resource.public_send(name), :frozen?
        assert_empty build(klass, :other, 1).public_send(name)
        assert_predicate build(klass, :other, 1).public_send(name), :frozen?
      end
    end

    def test_a_list_of_objects_that_is_not_a_list_raises
      each_reader(LISTS) do |klass, name|
        error = assert_raises(InvalidAttribute) { build(klass, name, {"key" => "value"}).public_send(name) }

        assert_equal "#{klass}##{name} cannot be read from {\"key\" => \"value\"}", error.message
        assert_equal "{\"key\" => \"value\"} is not a list", error.cause.message
      end
    end

    def test_a_list_that_holds_something_other_than_an_object_raises
      each_reader(LISTS) do |klass, name|
        error = assert_raises(InvalidAttribute) { build(klass, name, [{"key" => "value"}, "other"]).public_send(name) }

        assert_equal "#{klass}##{name} cannot be read from [{\"key\" => \"value\"}, \"other\"]", error.message
        assert_equal "\"other\" is not an object", error.cause.message
      end
    end

    def test_a_list_of_identifiers_is_not_read_as_a_list_of_objects
      assert_equal %w[a b], Place.new({"id" => "1", "contained_within" => %w[a b]}).contained_within
    end

    private

    # Call the block with each class and reader of a table
    def each_reader(table) = table.each { |klass, names| names.each { |name| yield klass, name } }

    # A resource of a class that holds a value under the name of a reader
    def build(klass, name, value)
      id = klass.equal?(Media) ? "3_1" : "1"
      klass.new({klass.equal?(Media) ? "media_key" : "id" => id, name.to_s => value})
    end
  end
end
