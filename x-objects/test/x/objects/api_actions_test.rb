require_relative "../../test_helper"

module X
  module Objects
    class APIActionsTest < Minitest::Test
      def test_includes_one_module_per_kind_of_action
        assert_equal [API::Actions::Engagement, API::Actions::Relationships, API::Actions::DirectMessages, API::Actions::Lists,
          API::Actions::Posts], API::Actions.ancestors.drop(1)
      end

      def test_relationships_is_the_client_module_not_the_resource_mixin
        refute_includes API::Actions.ancestors, Objects::Relationships
      end
    end
  end
end
