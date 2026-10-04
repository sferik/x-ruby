# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Resources
    class APIActionsTest < Minitest::Test
      def test_includes_one_module_per_kind_of_lookup_and_of_action
        assert_equal [Actions::Engagement, Actions::Relationships, Actions::DirectMessages, Actions::Lists, Actions::Posts,
          Lookups::Trends, Lookups::DirectMessages, Lookups::Communities, Lookups::Spaces, Lookups::Media, Lookups::Lists,
          Lookups::Posts, Lookups::Users], API.ancestors.drop(1)
      end

      def test_relationships_is_the_client_module_not_the_resource_mixin
        refute_includes API.ancestors, Resources.const_get(:Relationships)
      end

      def test_a_client_gains_no_constant_of_the_object_layer
        assert_empty API.ancestors.flat_map(&:constants)
      end

      def test_a_class_that_includes_api_gains_no_module_named_as_a_resource_is
        refute_includes FakeClient.constants, :Media
        refute_includes FakeClient.constants, :Users
      end
    end
  end
end
