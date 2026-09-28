# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A response that holds something other than an object where the API documents one, or other than a list where it
  # documents a list, raises InvalidAttribute from the reader of an attribute or a reference, as a value that cannot
  # be read does, rather than the NoMethodError or TypeError of reading into it
  class InvalidShapeTest < Minitest::Test
    cover Objects::Attributes
    cover Objects::Shape

    def test_an_attribute_read_through_something_other_than_an_object_raises
      error = assert_raises(InvalidAttribute) { User.new({"id" => "1", "public_metrics" => "many"}).followers_count }

      assert_equal "X::User#followers_count cannot be read from \"many\"", error.message
      assert_equal "\"many\" is not an object", error.cause.message
      assert_raises(InvalidAttribute) { User.new({"id" => "1", "public_metrics" => [1]}).followers_count }
    end

    def test_an_attribute_read_through_an_object_the_response_leaves_out_is_nil
      assert_nil User.new({"id" => "1"}).followers_count
      assert_equal 2, User.new({"id" => "1", "public_metrics" => {"followers_count" => 2}}).followers_count
    end

    def test_a_predicate_reads_its_attribute
      klass = Class.new(Resource) { attribute :flag, :boolean, key: %w[settings flag] }

      assert_predicate klass.new({"id" => "1", "settings" => {"flag" => true}}), :flag?
      refute_predicate klass.new({"id" => "1", "settings" => {"flag" => "true"}}), :flag?
      refute_predicate klass.new({"id" => "1"}), :flag?
    end

    def test_a_predicate_raises_as_its_reader_does
      klass = Class.new(Resource) { attribute :flag, :boolean, key: %w[settings flag] }
      error = assert_raises(InvalidAttribute) { klass.new({"id" => "1", "settings" => "on"}).flag? }

      assert_equal "#{klass}#flag cannot be read from \"on\"", error.message
    end

    def test_the_references_of_a_class_name_their_readers_when_read_through_something_other_than_an_object
      resource = references_class.new({"id" => "1", "details" => "none"})

      assert_equal "#{references_class}#owner cannot be read from \"none\"", assert_raises(InvalidAttribute) { resource.owner }.message
      assert_equal "#{references_class}#members cannot be read from \"none\"", assert_raises(InvalidAttribute) { resource.members }.message
    end

    def test_references_of_a_class_that_are_not_a_list_name_their_reader
      error = assert_raises(InvalidAttribute) { references_class.new({"id" => "1", "details" => {"member_ids" => "2"}}).members }

      assert_equal "#{references_class}#members cannot be read from \"2\"", error.message
    end

    def test_the_references_of_a_class_read_what_the_response_holds
      resource = references_class.new({"id" => "1", "details" => {"owner_id" => "2", "member_ids" => %w[3 4]}})

      assert_equal [2, [3, 4]], [resource.owner.id, resource.members.map(&:id)]
      assert_predicate resource.members, :frozen?
      assert_equal [nil, []], [references_class.new({"id" => "1"}).owner, references_class.new({"id" => "1"}).members]
    end

    def test_a_list_of_identifiers_that_is_not_a_list_raises
      error = assert_raises(InvalidAttribute) { Space.new({"id" => "a", "host_ids" => "1"}).host_ids }

      assert_equal ["X::Space#host_ids cannot be read from \"1\"", "\"1\" is not a list"], [error.message, error.cause.message]
      assert_raises(InvalidAttribute) { Space.new({"id" => "a", "host_ids" => {"1" => "2"}}).host_ids }
      assert_empty Space.new({"id" => "a"}).host_ids
    end

    def test_a_list_that_is_not_a_list_raises
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "context_annotations" => {"domain" => {}}}).context_annotations }

      assert_equal "X::Post#context_annotations cannot be read from {\"domain\" => {}}", error.message
      assert_empty Post.new({"id" => "1"}).context_annotations
    end

    def test_references_that_are_not_a_list_raise
      error = assert_raises(InvalidAttribute) { Space.new({"id" => "a", "host_ids" => "1"}).hosts }

      assert_equal "X::Space#hosts cannot be read from \"1\"", error.message
      assert_empty Space.new({"id" => "a"}).hosts
      assert_equal [1], Space.new({"id" => "a", "host_ids" => ["1"]}).hosts.map(&:id)
    end

    def test_references_read_through_something_other_than_an_object_raise
      error = assert_raises(InvalidAttribute) { DirectMessage.new({"id" => "1", "attachments" => "3_1"}).media }

      assert_equal "X::DirectMessage#media cannot be read from \"3_1\"", error.message
    end

    def test_a_reference_read_through_something_other_than_an_object_raises
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "geo" => "here"}).place }

      assert_equal "X::Post#place cannot be read from \"here\"", error.message
      assert_equal "a", Post.new({"id" => "1", "geo" => {"place_id" => "a"}}).place.id
    end

    private

    # A resource class with a reference and references read through an object
    def references_class
      @references_class ||= Class.new(Resource) do
        reference :owner, :User, key: %w[details owner_id]
        references :members, :User, key: %w[details member_ids]
      end
    end
  end
end
