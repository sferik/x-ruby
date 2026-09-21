# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class APIProblemForwardingTest < Minitest::Test
      cover API::Lookups
      cover X::User
      cover X::Objects::UserFinders

      PATHS = %w[tweets/1 lists/1 spaces/1 communities/1 dm_events/1 tweets spaces users].freeze

      def setup
        @client = FakeClient.new
        PATHS.each { |path| @client.stub(:get, path, {"errors" => [{"title" => path}]}) }
        @yielded = []
      end

      def test_single_finders_forward_the_block
        %i[find_post find_list find_space find_community find_direct_message].each { |finder| @client.public_send(finder, 1) { |problem| @yielded << problem.title } }

        assert_equal PATHS.first(5), @yielded
      end

      def test_user_find_all_forwards_the_block_to_both_lookups
        @client.stub(:get, "users/by", {"errors" => [{"title" => "users/by"}]})
        X::User.find_all([1, "nobody"], client: @client) { |problem| @yielded << problem.title }

        assert_equal %w[users users/by], @yielded
      end

      def test_batch_finders_forward_the_block
        %i[find_all_posts find_all_spaces find_all_users].each { |finder| @client.public_send(finder, [1]) { |problem| @yielded << problem.title } }

        assert_equal PATHS.last(3), @yielded
      end
    end
  end
end
