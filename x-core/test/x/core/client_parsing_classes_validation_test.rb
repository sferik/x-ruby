# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The classes a response is parsed into are checked when the client is built, and before a request is sent, rather
  # than once the API has answered it
  class ClientParsingClassesValidationTest < Minitest::Test
    cover_client
    cover Core.const_get(:SettingValidator)

    ARRAY_CLASS_MESSAGE = "%s must be a Class that JSON.parse builds each array into, such as Array, not %s"
    OBJECT_CLASS_MESSAGE = "%s must be a Class that JSON.parse builds each object into, such as Hash, or respond to " \
      "from_response, as the resource classes of x-objects do, not %s"

    # What builds the result of a request from the whole body, as a resource class of x-objects does
    module Builder
      def self.from_response(body, client:, **) = [body, client]
    end

    def message_of(&) = assert_raises(ArgumentError, &).message

    def test_a_default_array_class_that_is_not_a_class_is_refused_when_the_client_is_built
      assert_equal format(ARRAY_CLASS_MESSAGE, :default_array_class, "5"), message_of { Client.new(default_array_class: 5) }
      assert_equal format(ARRAY_CLASS_MESSAGE, :default_array_class, '"Array"'), message_of { Client.new(default_array_class: "Array") }
      assert_equal format(ARRAY_CLASS_MESSAGE, :default_array_class, "X::ClientParsingClassesValidationTest::Builder"),
        message_of { Client.new(default_array_class: Builder) }
    end

    def test_a_default_object_class_that_is_neither_a_class_nor_builds_a_result_is_refused_when_the_client_is_built
      assert_equal format(OBJECT_CLASS_MESSAGE, :default_object_class, '"Hash"'), message_of { Client.new(default_object_class: "Hash") }
      assert_equal format(OBJECT_CLASS_MESSAGE, :default_object_class, "nil"), message_of { Client.new(default_object_class: nil) }
      assert_raises(ArgumentError) { Client.new.with(default_object_class: Comparable) }
    end

    def test_a_class_or_what_builds_a_result_is_allowed
      client = Client.new(default_array_class: Set, default_object_class: Builder)

      assert_equal [Set, Builder], [client.default_array_class, client.default_object_class]
      assert_equal OpenStruct, Client.new(default_object_class: OpenStruct).default_object_class
    end

    def test_the_classes_of_a_request_are_checked_before_it_is_sent
      client = Client.new

      assert_equal format(ARRAY_CLASS_MESSAGE, :array_class, "5"), message_of { client.get("users/me", array_class: 5) }
      assert_equal format(OBJECT_CLASS_MESSAGE, :object_class, '"Hash"'), message_of { client.post("tweets", object_class: "Hash") }
      assert_raises(ArgumentError) { client.put("tweets/1", array_class: nil) }
      assert_raises(ArgumentError) { client.delete("tweets/1", object_class: nil) }
      assert_not_requested :any, /api\.x\.com/
    end
  end
end
