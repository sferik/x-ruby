# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class FindersConcurrencyTest < Minitest::Test
      cover Finders
      cover UserFinders
      cover X::Media
      cover API::Lookups

      def setup
        @client = FakeClient.new
      end

      def test_find_all_looks_batches_up_at_the_concurrency_given
        @client.stub(:get, "users", {"data" => []})

        assert_equal 2, concurrency_of { User.find_all([1, 2], client: @client, concurrency: 2) }
      end

      def test_find_all_looks_batches_up_four_at_a_time_by_default
        @client.stub(:get, "users", {"data" => []})

        assert_equal 4, concurrency_of { User.find_all([1, 2], client: @client) }
      end

      def test_the_default_concurrency_is_four_and_named_by_the_finders_alone
        assert_equal [4, 100], [Finders::DEFAULT_CONCURRENCY, Finders::MAX_BATCH_SIZE]
        refute Resource.const_defined?(:DEFAULT_CONCURRENCY) || Resource.const_defined?(:MAX_BATCH_SIZE)
      end

      def test_find_all_refuses_a_concurrency_below_one
        error = assert_raises(ArgumentError) { User.find_all([1], client: @client, concurrency: 0) }

        assert_equal "concurrency must be an Integer of at least 1, not 0", error.message
      end

      def test_find_all_refuses_a_concurrency_that_is_not_an_integer
        error = assert_raises(ArgumentError) { User.find_all([1], client: @client, concurrency: 1.5) }

        assert_equal "concurrency must be an Integer of at least 1, not 1.5", error.message
      end

      def test_find_all_does_not_send_the_concurrency_as_a_query_parameter
        @client.stub(:get, "users", {"data" => []})
        User.find_all([1], client: @client, concurrency: 1)

        refute_includes @client.queries.first, "concurrency"
      end

      def test_find_all_by_username_takes_a_concurrency
        @client.stub(:get, "users/by", {"data" => []})

        assert_equal 2, concurrency_of { User.find_all_by_username(%w[sferik gem], client: @client, concurrency: 2) }
      end

      def test_find_all_by_username_refuses_a_concurrency_below_one
        assert_raises(ArgumentError) { User.find_all_by_username(%w[sferik], client: @client, concurrency: 0) }
      end

      def test_find_all_passes_one_concurrency_to_the_lookups_of_both_kinds
        @client.stub(:get, "users", {"data" => []}).stub(:get, "users/by", {"data" => []})

        assert_equal [2, 2], every_concurrency_of { User.find_all([1, "sferik"], client: @client, concurrency: 2) }
      end

      def test_hydrate_all_takes_a_concurrency
        @client.stub(:get, "users", {"data" => []})

        assert_equal 2, concurrency_of { User.hydrate_all([User.from_id(1)], client: @client, concurrency: 2) }
      end

      def test_find_users_takes_a_concurrency
        @client.stub(:get, "users", {"data" => []})

        assert_equal 2, concurrency_of { @client.find_all_users([1], concurrency: 2) }
      end

      def test_find_users_defaults_to_four_batches_at_once
        @client.stub(:get, "users", {"data" => []})

        assert_equal 4, concurrency_of { @client.find_all_users([1]) }
      end

      def test_find_users_by_username_takes_a_concurrency
        @client.stub(:get, "users/by", {"data" => []})

        assert_equal 2, concurrency_of { @client.find_all_users_by_username(%w[sferik], concurrency: 2) }
      end

      def test_find_users_by_username_defaults_to_four_batches_at_once
        @client.stub(:get, "users/by", {"data" => []})

        assert_equal 4, concurrency_of { @client.find_all_users_by_username(%w[sferik]) }
      end

      def test_find_posts_takes_a_concurrency
        @client.stub(:get, "tweets", {"data" => []})

        assert_equal 2, concurrency_of { @client.find_all_posts([1], concurrency: 2) }
      end

      def test_find_posts_defaults_to_four_batches_at_once
        @client.stub(:get, "tweets", {"data" => []})

        assert_equal 4, concurrency_of { @client.find_all_posts([1]) }
      end

      def test_find_spaces_takes_a_concurrency
        @client.stub(:get, "spaces", {"data" => []})

        assert_equal 2, concurrency_of { @client.find_all_spaces(%w[1DXxyRYNejbKM], concurrency: 2) }
      end

      def test_find_spaces_defaults_to_four_batches_at_once
        @client.stub(:get, "spaces", {"data" => []})

        assert_equal 4, concurrency_of { @client.find_all_spaces(%w[1DXxyRYNejbKM]) }
      end

      def test_find_all_media_takes_a_concurrency
        @client.stub(:get, "media", {"data" => []})

        assert_equal 2, concurrency_of { @client.find_all_media(%w[3_1], concurrency: 2) }
      end

      def test_find_all_media_defaults_to_four_batches_at_once
        @client.stub(:get, "media", {"data" => []})

        assert_equal 4, concurrency_of { @client.find_all_media(%w[3_1]) }
      end

      private

      # The concurrency the lookups of the block gave the thread pool
      def concurrency_of(&) = every_concurrency_of(&).first

      # The concurrency of each lookup the block made, in the order they were made
      def every_concurrency_of(&)
        given = []
        original = Parallel.method(:map)
        Parallel.stub(:map, lambda { |items, concurrency:, &block|
          given << concurrency
          original.call(items, concurrency:, &block)
        }, &)
        given
      end
    end
  end
end
