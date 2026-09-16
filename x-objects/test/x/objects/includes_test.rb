require_relative "../../test_helper"

module X
  module Objects
    class IncludesTest < Minitest::Test
      cover Includes

      def setup
        @client = FakeClient.new
        @includes = Includes.new({"users" => [{"id" => "1", "username" => "sferik"}], "media" => [{"media_key" => "3_1"}]})
      end

      def test_resolve_included_resource
        user = @includes.resolve(User, "1", client: @client)

        assert_equal({"id" => "1", "username" => "sferik"}, user.attrs)
        assert_same @client, user.client
        assert_same @includes, user.send(:includes)
        refute_predicate user, :hydrated?
      end

      def test_resolve_stub_when_not_included
        user = @includes.resolve(User, "2", client: @client)

        assert_equal({"id" => "2"}, user.attrs)
        assert_same @client, user.client
        assert_same @includes, user.send(:includes)
      end

      def test_resolve_is_an_identity_map
        assert_same @includes.resolve(User, "1", client: @client), @includes.resolve(User, "1", client: @client)
        assert_same @includes.resolve(User, "2", client: @client), @includes.resolve(User, "2", client: @client)
      end

      def test_resolve_keys_by_class
        refute_same @includes.resolve(User, "1", client: @client), @includes.resolve(Post, "1", client: @client)
        assert_instance_of Post, @includes.resolve(Post, "1", client: @client)
      end

      def test_resolve_uses_id_key_of_class
        assert_equal({"media_key" => "3_1"}, @includes.resolve(Media, "3_1", client: @client).attrs)
        assert_equal({"media_key" => "3_2"}, @includes.resolve(Media, "3_2", client: @client).attrs)
      end

      def test_resolve_stub_for_class_without_includes_key
        assert_equal({"id" => "1"}, @includes.resolve(List, "1", client: @client).attrs)
      end

      def test_resolve_first_of_duplicates
        includes = Includes.new({"users" => [{"id" => "1", "name" => "first"}, {"id" => "1", "name" => "second"}]})

        assert_equal "first", includes.resolve(User, "1", client: @client).name
      end

      def test_resolve_ignores_entries_without_id
        includes = Includes.new({"users" => [{"username" => "anonymous"}, {"id" => "1"}]})

        assert_equal({"id" => "1"}, includes.resolve(User, "1", client: @client).attrs)
      end

      def test_resolve_without_data
        assert_equal({"id" => "1"}, Includes.new.resolve(User, "1", client: @client).attrs)
        assert_equal({"id" => "1"}, Includes.new(nil).resolve(User, "1", client: @client).attrs)
      end

      def test_resolve_accepts_symbol_keys
        includes = Includes.new({users: [{id: "1", username: "sferik"}]})

        assert_equal "sferik", includes.resolve(User, "1", client: @client).username
      end

      def test_resolve_builds_one_resource_across_threads
        slow = Class.new(User) do
          def initialize(...)
            sleep 0.01
            super
          end
        end
        resources = Array.new(4) { Thread.new { @includes.resolve(slow, "1", client: @client) } }.map(&:value)

        assert_equal 1, resources.uniq(&:object_id).size
      end

      def test_frozen
        assert_predicate @includes, :frozen?
      end
    end
  end
end
