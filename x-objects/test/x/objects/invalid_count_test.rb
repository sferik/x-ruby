# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A count, a date of usage, a timestamp, or the event a sent message created, that a response holds but cannot be
  # read as what the API documents it to be raises InvalidAttribute where it is read, as the attributes of a resource do
  class InvalidCountTest < Minitest::Test
    cover Objects::PostCounts
    cover Objects::DirectMessageConversations
    cover Objects::Utils
    cover Usage

    def setup
      @client = FakeClient.new
    end

    def test_a_period_whose_start_cannot_be_read_raises
      error = period_error({"start" => "yesterday", "tweet_count" => 1})

      assert_equal "A period of the counts of X::Post cannot be read from {\"start\" => \"yesterday\", \"tweet_count\" => 1}", error.message
      assert_instance_of ArgumentError, error.cause
      assert_instance_of InvalidAttribute, period_error({"start" => 20_260_101, "tweet_count" => 1})
      assert_instance_of InvalidAttribute, period_error({"tweet_count" => 1})
    end

    def test_a_period_whose_count_cannot_be_read_raises
      start = "2026-01-01T00:00:00.000Z"

      assert_instance_of InvalidAttribute, period_error({"start" => start, "tweet_count" => "a"})
      assert_instance_of InvalidAttribute, period_error({"start" => start})
      assert_instance_of InvalidAttribute, period_error({"start" => start, "post_count" => 1.5})
    end

    def test_a_period_reads_a_count_the_api_names_for_either_as_a_number_in_base_ten
      @client.stub(:get, "tweets/counts/recent", {"data" => [{"start" => "2026-01-01T00:00:00.000Z", "post_count" => "019"}]})

      assert_equal({Time.utc(2026) => 19}, Post.count_by_period("ruby", client: @client))
    end

    def test_a_total_that_cannot_be_read_raises
      @client.stub(:get, "tweets/counts/recent", {"meta" => {"total_tweet_count" => "many"}})
      error = assert_raises(InvalidAttribute) { Post.count("ruby", client: @client) }

      assert_equal "The total of the counts of X::Post cannot be read from \"many\"", error.message
    end

    def test_a_total_given_as_a_string_of_digits_is_read_as_a_number
      @client.stub(:get, "tweets/counts/recent", {"meta" => {"total_post_count" => "3"}})

      assert_equal 3, Post.count("ruby", client: @client)
    end

    def test_a_day_of_usage_without_a_date_raises_where_it_is_read
      usage = Usage.new({"daily_project_usage" => {"usage" => [{"usage" => "1"}]}})

      assert_equal "X::Usage#daily cannot be read from nil", assert_raises(InvalidAttribute) { usage.daily }.message
      assert_raises(InvalidAttribute) { Usage.new({"daily_project_usage" => {"usage" => [{"date" => 1, "usage" => "1"}]}}).daily }
    end

    def test_a_timestamp_that_is_a_number_raises_where_it_is_read
      error = assert_raises(InvalidAttribute) { Post.new({"id" => "1", "created_at" => 1_700_000_000}).created_at }

      assert_equal "X::Post#created_at cannot be read from 1700000000", error.message
    end

    def test_a_sent_message_without_an_event_raises_where_it_is_read
      @client.stub(:post, "dm_conversations", {"data" => {"dm_conversation_id" => "9", "dm_event_id" => "abc"}})
      error = assert_raises(InvalidAttribute) { DirectMessage.create_group(%w[1 2], "Hi", client: @client) }

      assert_equal "X::DirectMessage#id cannot be read from \"abc\"", error.message
    end

    private

    # The error a count by period raises for a response that holds one period
    def period_error(period)
      @client.stub(:get, "tweets/counts/recent", {"data" => [period]})
      assert_raises(InvalidAttribute) { Post.count_by_period("ruby", client: @client) }
    end
  end
end
