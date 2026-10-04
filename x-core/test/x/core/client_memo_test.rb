# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientMemoTest < Minitest::Test
    cover_client
    cover Core.const_get(:ClientMemo)

    KEY = :x_resources_current_user_id

    def test_a_client_keeps_nothing_until_a_value_is_kept
      assert_nil Client.new(bearer_token: TEST_BEARER_TOKEN).memoized(KEY)
    end

    def test_a_client_reads_the_value_it_kept_under_its_key
      client = Client.new(**test_oauth_credentials)

      assert_equal 9, client.memoize(KEY, 9)
      assert_equal [9, nil], [client.memoized(KEY), client.memoized(:another_key)]
    end

    def test_a_value_kept_again_replaces_the_one_before
      client = Client.new(**test_oauth_credentials)
      client.memoize(KEY, 9)
      client.memoize(KEY, 10)

      assert_equal 10, client.memoized(KEY)
    end

    def test_a_value_is_read_only_with_the_authenticator_it_was_kept_with
      client = Client.new(**test_oauth_credentials)
      client.memoize(KEY, 9)
      internals(client).instance_variable_set(:@authenticator, OAuth1Authenticator.new(**test_oauth_credentials))

      assert_nil client.memoized(KEY)
    end

    def test_a_frozen_client_keeps_values
      client = Client.new(**test_oauth_credentials).freeze
      client.memoize(KEY, 9)

      assert_equal 9, client.memoized(KEY)
    end

    def test_a_copy_made_with_dup_or_clone_shares_the_values_of_the_client
      client = Client.new(**test_oauth_credentials)
      copies = [client.dup, client.clone]
      client.memoize(KEY, 9)

      assert_equal [9, 9], copies.map { |copy| copy.memoized(KEY) }
    end

    def test_a_copy_made_with_with_keeps_values_of_its_own
      client = Client.new(**test_oauth2_credentials)
      client.memoize(KEY, 9)
      copy = client.with(base_url: "https://api.x.com/1.1/")
      copy.memoize(KEY, 10)

      assert_equal [9, 10], [client.memoized(KEY), copy.memoized(KEY)]
    end

    # Run the block on a thread while the lock of the memo of the client is held, and return the thread, which waits
    def waiting_for_the_lock(client, &)
      internals(client).instance_variable_get(:@memo_lock).synchronize do
        Thread.new(&).tap { |thread| assert_nil thread.join(0.05) }
      end
    end

    def test_values_are_read_and_kept_under_a_lock
      client = Client.new(**test_oauth_credentials)
      client.memoize(KEY, 9)
      reader = waiting_for_the_lock(client) { client.memoized(KEY) }
      writer = waiting_for_the_lock(client) { client.memoize(KEY, 10) }

      assert_equal [9, 10, 10], [reader.value, writer.value, client.memoized(KEY)]
    end
  end
end
