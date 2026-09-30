# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The days of usage, and the periods and meta of counts, that are not lists of objects, or objects, where the API
  # documents them to be raise InvalidAttribute where they are read
  class InvalidShapeUsageTest < Minitest::Test
    cover Objects.const_get(:PostCounts)
    cover Objects.const_get(:Shape)
    cover PostUsage

    def setup
      @client = FakeClient.new
    end

    def test_daily_usage_read_through_something_other_than_an_object_raises
      error = assert_raises(InvalidAttribute) { PostUsage.new({"daily_project_usage" => "none"}).daily }

      assert_equal "X::PostUsage#daily cannot be read from \"none\"", error.message
      assert_empty PostUsage.new({}).daily
    end

    def test_daily_usage_that_is_not_a_list_of_objects_raises
      assert_equal "X::PostUsage#daily cannot be read from \"none\"", assert_raises(InvalidAttribute) { daily("none") }.message
      assert_raises(InvalidAttribute) { daily([1]) }
      assert_raises(InvalidAttribute) { daily([nil]) }
    end

    def test_usage_by_app_that_is_not_a_list_of_objects_raises
      error = assert_raises(InvalidAttribute) { PostUsage.new({"daily_client_app_usage" => "none"}).daily_by_app }

      assert_equal ["X::PostUsage#daily_by_app cannot be read from \"none\"", "\"none\" is not a list"], [error.message, error.cause.message]
      assert_raises(InvalidAttribute) { PostUsage.new({"daily_client_app_usage" => {"client_app_id" => "1"}}).daily_by_app }
      assert_raises(InvalidAttribute) { PostUsage.new({"daily_client_app_usage" => ["1"]}).daily_by_app }
      assert_empty PostUsage.new({}).daily_by_app
    end

    def test_the_days_of_an_app_that_cannot_be_read_name_the_reader_that_reads_them
      usage = PostUsage.new({"daily_client_app_usage" => [{"client_app_id" => "1", "usage" => "none"}]})

      assert_equal "X::PostUsage#daily_by_app cannot be read from \"none\"", assert_raises(InvalidAttribute) { usage.daily_by_app }.message
      usage = PostUsage.new({"daily_client_app_usage" => [{"client_app_id" => "1", "usage" => [{"usage" => "1"}]}]})

      assert_equal "X::PostUsage#daily_by_app cannot be read from nil", assert_raises(InvalidAttribute) { usage.daily_by_app }.message
    end

    def test_counts_by_period_that_are_not_a_list_of_objects_raise
      @client.stub(:get, "tweets/counts/recent", {"data" => [1]})
      error = assert_raises(InvalidAttribute) { Post.count_by_period("ruby", client: @client) }

      assert_equal "A period of the counts of X::Post cannot be read from [1]", error.message
      @client.stub(:get, "tweets/counts/recent", {"data" => {"start" => "2026-01-01T00:00:00.000Z"}})

      assert_raises(InvalidAttribute) { Post.count_by_period("ruby", client: @client) }
    end

    def test_a_meta_that_is_not_an_object_raises
      @client.stub(:get, "tweets/counts/recent", {"meta" => "many"})
      error = assert_raises(InvalidAttribute) { Post.count("ruby", client: @client) }

      assert_equal "The next page of the counts of X::Post cannot be read from \"many\"", error.message
    end

    private

    # The daily usage of a response whose daily project usage holds the days given
    def daily(days) = PostUsage.new({"daily_project_usage" => {"usage" => days}}).daily
  end
end
