require_relative "../../test_helper"

module X
  module Objects
    class AttributesReferencesTest < Minitest::Test
      cover Attributes

      def setup
        @client = FakeClient.new
        @includes = Includes.new({"users" => [{"id" => "2", "username" => "two"}]})
        @klass = Class.new(Resource) do
          reference :owner, :User, key: %w[owner_id]
          reference :nested_owner, :User, key: %w[meta owner_id]
          references :members, :User, key: %w[member_ids]
          references :nested_members, :User, key: %w[meta member_ids]
        end
        @widget = @klass.new({"id" => "1", "owner_id" => "9", "meta" => {"owner_id" => "8", "member_ids" => ["7"]},
                              "member_ids" => %w[2 3]}, client: @client, includes: @includes)
      end

      def test_string_keys_are_rejected
        assert_raises(ArgumentError) { Class.new(Resource) { reference :owner, :User, key: "owner_id" } }
        assert_raises(ArgumentError) { Class.new(Resource) { references :members, :User, key: "member_ids" } }
      end

      def test_reference_builds_stub
        owner = @widget.owner

        assert_instance_of User, owner
        assert_equal({"id" => "9"}, owner.attrs)
        assert_same @client, owner.client
      end

      def test_reference_is_memoized
        assert_same @widget.owner, @widget.owner
      end

      def test_reference_with_nested_key
        assert_equal 8, @widget.nested_owner.id
      end

      def test_missing_reference
        assert_nil @klass.new({"id" => "1"}).owner
        assert_nil @klass.new({"id" => "1", "meta" => {}}).nested_owner
      end

      def test_references_resolve_from_includes_and_stubs
        members = @widget.members

        assert_equal [2, 3], members.map(&:id)
        assert_equal ["two", nil], members.map(&:username)
        assert(members.all?(User))
        assert_same @client, members.last.client
      end

      def test_references_are_frozen_and_share_identity
        assert_predicate @widget.members, :frozen?
        assert_same @widget.members.last, @widget.members.last
        assert_same @widget.members.first, @includes.resolve(User, "2", client: @client)
      end

      def test_references_with_nested_key
        assert_equal [7], @widget.nested_members.map(&:id)
      end

      def test_missing_references
        assert_empty @klass.new({"id" => "1"}).members
        assert_empty @klass.new({"id" => "1", "meta" => {}}).nested_members
      end

      def test_memo_keys_are_separate
        assert_equal 9, @widget.owner.id
        assert_equal 8, @widget.nested_owner.id
        assert_equal [2, 3], @widget.members.map(&:id)
        assert_equal [7], @widget.nested_members.map(&:id)
      end
    end
  end
end
