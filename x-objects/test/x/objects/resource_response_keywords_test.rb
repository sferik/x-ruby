# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class ResourceResponseKeywordsTest < Minitest::Test
      cover Resource

      def test_from_response_ignores_keywords_a_later_x_core_may_pass
        client = FakeClient.new
        user = User.from_response({"data" => {"id" => "1"}}, client:, request: :request)

        assert_equal 1, user.id
        assert_same client, user.client
      end
    end
  end
end
