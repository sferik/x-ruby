# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class ErrorsTest < Minitest::Test
      cover MissingResource
      cover Resource
      cover Objects::Finders
      cover API::Lookups

      def setup
        @client = FakeClient.new
      end

      def test_not_found_is_an_x_error
        assert_operator MissingResource, :<, X::Error
        assert_operator X::Error, :<, StandardError
      end

      def test_every_error_of_the_object_layer_descends_from_its_own_base
        assert_operator MissingResource, :<, Objects::Error
        assert_operator Objects::Error, :<, X::Error
      end

      # The object layer's own base class shares the name of x-core's, so a rescue inside X::Objects that means every
      # error of the API, such as the one the connection status of a user falls back from, must name X::Error.
      def test_the_base_of_the_object_layer_catches_none_of_the_errors_of_x_core
        refute_operator X::Error, :<, Objects::Error
        refute_operator UnsupportedOperation, :<, Objects::Error
      end

      def test_unsupported_operation_is_an_x_error
        assert_operator UnsupportedOperation, :<, X::Error
      end

      def test_find_bang
        @client.stub(:get, "users/1", {"data" => {"id" => "1", "username" => "sferik"}})

        assert_equal "sferik", User.find!(1, client: @client, "user.fields": "id").username
        assert_equal "id", @client.queries.first["user.fields"]
      end

      def test_find_bang_by_username
        @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "1", "username" => "sferik"}})

        assert_equal 1, User.find!("sferik", client: @client).id
      end

      def test_find_bang_not_found
        @client.stub(:get, "tweets/1", {"errors" => []})
        error = assert_raises(MissingResource) { Post.find!(1, client: @client) }

        assert_equal "Could not find X::Post 1", error.message
      end

      def test_find_user_bang
        @client.stub(:get, "users/by/username/nobody", {"errors" => []})
        @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "1", "username" => "sferik"}})

        assert_equal "sferik", @client.find_user!("sferik", "user.fields": "id").username
        assert_equal "id", @client.queries.first["user.fields"]
        assert_raises(MissingResource) { @client.find_user!("nobody") }
      end

      def test_find_post_bang
        @client.stub(:get, "tweets/1", {"data" => {"id" => "1", "text" => "hi"}})
        @client.stub(:get, "tweets/2", {"errors" => []})

        assert_equal "hi", @client.find_post!(1, "post.fields": "id").text
        assert_equal "id", @client.queries.first["post.fields"]
        assert_raises(MissingResource) { @client.find_post!(2) }
      end

      def test_find_media_bang
        @client.stub(:get, "media/3_1", {"data" => {"media_key" => "3_1", "type" => "photo"}})
        @client.stub(:get, "media/3_2", {"errors" => []})

        assert_equal "photo", @client.find_media!("3_1", "media.fields": "type").type
        assert_equal "type", @client.queries.first["media.fields"]
        assert_raises(MissingResource) { @client.find_media!("3_2") }
      end

      def test_find_space_bang
        @client.stub(:get, "spaces/1", {"data" => {"id" => "1", "title" => "Ruby"}})
        @client.stub(:get, "spaces/2", {"errors" => []})

        assert_equal "Ruby", @client.find_space!("1", "space.fields": "id").title
        assert_equal "id", @client.queries.first["space.fields"]
        assert_raises(MissingResource) { @client.find_space!("2") }
      end

      def test_find_direct_message_bang
        @client.stub(:get, "dm_events/1", {"data" => {"id" => "1", "text" => "hi"}})
        @client.stub(:get, "dm_events/2", {"errors" => []})

        assert_equal "hi", @client.find_direct_message!("1", "dm_event.fields": "id").text
        assert_equal "id", @client.queries.first["dm_event.fields"]
        assert_raises(MissingResource) { @client.find_direct_message!("2") }
      end

      def test_find_list_bang
        @client.stub(:get, "lists/1", {"data" => {"id" => "1", "name" => "Ruby"}})
        @client.stub(:get, "lists/2", {"errors" => []})

        assert_equal "Ruby", @client.find_list!(1, "list.fields": "id").name
        assert_equal "id", @client.queries.first["list.fields"]
        assert_raises(MissingResource) { @client.find_list!(2) }
      end

      def test_current_user_missing_raises_not_found
        @client.stub(:get, "users/me", {"errors" => []})
        error = assert_raises(MissingResource) { @client.current_user }

        assert_equal "users/me returned no user", error.message
      end
    end
  end
end
