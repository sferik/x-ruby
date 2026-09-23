# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A refreshed cursor reads the number the API publishes for its collection again, since the collection may have
  # changed, once
  class CursorRefreshCountTest < Minitest::Test
    cover Cursor
    cover Resource
    cover Objects::PublishedCount

    def setup
      @client = FakeClient.new
      @user = User.new({"id" => "1", "public_metrics" => {"followers_count" => 12}}, client: @client)
    end

    def test_a_refreshed_cursor_reads_the_number_the_api_publishes_again_once
      @client.stub(:get, "users/1", {"data" => {"id" => "1", "public_metrics" => {"followers_count" => 13}}})
      followers = @user.followers.refresh

      assert_equal [13, 13, 13], [followers.published_count, followers.published_count, followers.prefetch.published_count]
      assert_equal [12, %w[users/1]], [@user.followers.published_count, @client.paths]
    end

    def test_a_cursor_refreshed_again_reads_the_number_again
      @client.stub(:get, "users/1", {"data" => {"id" => "1", "public_metrics" => {"followers_count" => 13}}})
      followers = @user.followers.refresh
      followers.published_count
      @client.stub(:get, "users/1", {"data" => {"id" => "1", "public_metrics" => {"followers_count" => 14}}})

      assert_equal [14, 13], [followers.refresh.published_count, followers.published_count]
      assert_equal %w[users/1 users/1], @client.paths
    end

    def test_a_refreshed_cursor_over_the_collection_of_a_resource_that_is_gone_has_no_number
      @client.stub(:get, "users/1", {"errors" => [{"detail" => "Could not find user with id: [1]."}]})

      assert_nil @user.followers.refresh.published_count
    end

    def test_a_refreshed_cursor_over_a_collection_the_api_publishes_no_number_for_has_none
      assert_nil @user.muting.refresh.published_count
      assert_empty @client.requests
    end
  end
end
