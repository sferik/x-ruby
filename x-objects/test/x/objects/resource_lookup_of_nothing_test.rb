# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    # A lookup answered with no object that holds an identifier finds nothing, as X answers the lookup of a user that
    # does not exist when it asks for a field the client may not read
    class ResourceLookupOfNothingTest < Minitest::Test
      cover Objects.const_get(:Finders)

      def setup
        @client = FakeClient.new
      end

      def test_find_of_a_resource_answered_with_data_that_holds_no_identifier_is_nil
        unauthorized = {"title" => "Field Authorization Error", "type" => "https://api.x.com/2/problems/not-authorized-for-field",
                        "detail" => "Sorry, you are not authorized to access 'parody' on the user with id : [9].", "field" => "parody"}
        @client.stub(:get, "users/9", {"data" => {"created_at" => "1970-01-01T00:00:00.000Z", "verified" => false}, "errors" => [unauthorized]})
        problems = []

        assert_nil User.find(9, client: @client) { |problem| problems << problem }
        assert_equal ["Field Authorization Error"], problems.map(&:title)
      end

      def test_find_of_media_answered_with_data_that_holds_no_media_key_is_nil
        @client.stub(:get, "media/3_1", {"data" => {"id" => "1"}})

        assert_nil Media.find("3_1", client: @client)
      end

      def test_find_bang_of_a_resource_answered_with_data_that_holds_no_identifier_raises
        @client.stub(:get, "users/9", {"data" => {"verified" => false}})

        assert_raises(MissingResource) { User.find!(9, client: @client) }
      end

      def test_find_of_a_resource_answered_with_data_that_is_no_object_is_nil
        @client.stub(:get, "users/9", {"data" => [{"id" => "9"}]})

        assert_nil User.find(9, client: @client)
      end

      def test_find_of_a_resource_answered_with_no_body_is_nil
        @client.stub(:get, "users/9", nil)

        assert_nil User.find(9, client: @client)
      end
    end
  end
end
