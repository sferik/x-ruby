require_relative "../../test_helper"

module X
  module Objects
    class ErrorsTest < Minitest::Test
      cover ResourceNotFound
      cover Resource
      cover Objects::Finders
      cover API::Lookups

      def setup
        @client = FakeClient.new
      end

      def test_not_found_is_an_x_error
        assert_operator ResourceNotFound, :<, X::Error
        assert_operator X::Error, :<, StandardError
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
        error = assert_raises(ResourceNotFound) { Post.find!(1, client: @client) }

        assert_equal "Could not find X::Post 1", error.message
      end

      def test_find_user_bang
        @client.stub(:get, "users/by/username/nobody", {"errors" => []})
        @client.stub(:get, "users/by/username/sferik", {"data" => {"id" => "1", "username" => "sferik"}})

        assert_equal "sferik", @client.find_user!("sferik", "user.fields": "id").username
        assert_equal "id", @client.queries.first["user.fields"]
        assert_raises(ResourceNotFound) { @client.find_user!("nobody") }
      end

      def test_find_post_bang
        @client.stub(:get, "tweets/1", {"data" => {"id" => "1", "text" => "hi"}})
        @client.stub(:get, "tweets/2", {"errors" => []})

        assert_equal "hi", @client.find_post!(1, "post.fields": "id").text
        assert_equal "id", @client.queries.first["post.fields"]
        assert_raises(ResourceNotFound) { @client.find_post!(2) }
      end

      def test_find_space_bang
        @client.stub(:get, "spaces/1", {"data" => {"id" => "1", "title" => "Ruby"}})
        @client.stub(:get, "spaces/2", {"errors" => []})

        assert_equal "Ruby", @client.find_space!("1", "space.fields": "id").title
        assert_equal "id", @client.queries.first["space.fields"]
        assert_raises(ResourceNotFound) { @client.find_space!("2") }
      end

      def test_find_direct_message_bang
        @client.stub(:get, "dm_events/1", {"data" => {"id" => "1", "text" => "hi"}})
        @client.stub(:get, "dm_events/2", {"errors" => []})

        assert_equal "hi", @client.find_direct_message!("1", "dm_event.fields": "id").text
        assert_equal "id", @client.queries.first["dm_event.fields"]
        assert_raises(ResourceNotFound) { @client.find_direct_message!("2") }
      end

      def test_find_list_bang
        @client.stub(:get, "lists/1", {"data" => {"id" => "1", "name" => "Ruby"}})
        @client.stub(:get, "lists/2", {"errors" => []})

        assert_equal "Ruby", @client.find_list!(1, "list.fields": "id").name
        assert_equal "id", @client.queries.first["list.fields"]
        assert_raises(ResourceNotFound) { @client.find_list!(2) }
      end

      def test_current_user_missing_raises_not_found
        @client.stub(:get, "users/me", {"errors" => []})
        error = assert_raises(ResourceNotFound) { @client.current_user }

        assert_equal "users/me returned no user", error.message
      end
    end
  end
end
