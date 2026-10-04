# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A count, a date of usage, a timestamp, or the event a sent message created, that a response holds but cannot be
  # read as what the API documents it to be raises InvalidAttribute where it is read, as the attributes of a resource do
  class InvalidCountTest < Minitest::Test
    cover Resources.const_get(:PostCounts)
    cover Resources.const_get(:DirectMessageConversations)
    cover Resources.const_get(:Utils)
    cover PostUsage

    START_OF_PERIOD = "2026-01-01T00:00:00.000Z"
    END_OF_PERIOD = "2026-01-02T00:00:00.000Z"

    def setup
      @client = FakeClient.new
    end

    def test_a_period_whose_start_cannot_be_read_raises
      error = period_error({"start" => "yesterday", "end" => END_OF_PERIOD, "tweet_count" => 1})

      assert_equal "A period of the counts of X::Post cannot be read from #{{"start" => "yesterday", "end" => END_OF_PERIOD, "tweet_count" => 1}.inspect}", error.message
      assert_instance_of ArgumentError, error.cause
      assert_instance_of InvalidAttribute, period_error({"start" => 20_260_101, "end" => END_OF_PERIOD, "tweet_count" => 1})
      assert_instance_of InvalidAttribute, period_error({"end" => END_OF_PERIOD, "tweet_count" => 1})
    end

    def test_a_period_whose_end_cannot_be_read_raises
      assert_instance_of InvalidAttribute, period_error({"start" => START_OF_PERIOD, "end" => "tomorrow", "tweet_count" => 1})
      assert_instance_of InvalidAttribute, period_error({"start" => START_OF_PERIOD, "end" => 20_260_102, "tweet_count" => 1})
      assert_instance_of InvalidAttribute, period_error({"start" => START_OF_PERIOD, "tweet_count" => 1})
    end

    def test_a_period_whose_count_cannot_be_read_raises
      period = {"start" => START_OF_PERIOD, "end" => END_OF_PERIOD}

      assert_instance_of InvalidAttribute, period_error(period.merge("tweet_count" => "a"))
      assert_instance_of InvalidAttribute, period_error(period)
      assert_instance_of InvalidAttribute, period_error(period.merge("post_count" => 1.5))
      assert_equal "a period needs a count", period_error(period).cause.message
    end

    def test_a_period_refuses_a_count_every_other_count_is_refused_for
      period = {"start" => START_OF_PERIOD, "end" => END_OF_PERIOD}

      [" 1_2 ", "1_2", " 12", "-1", "+1", -1].each do |count|
        assert_equal "invalid value for Integer(): #{count.to_s.inspect}", period_error(period.merge("tweet_count" => count)).cause.message
      end
    end

    def test_a_period_reads_a_count_the_api_names_for_either_as_a_number_in_base_ten
      @client.stub(:get, "tweets/counts/recent", {"data" => [{"start" => START_OF_PERIOD, "end" => END_OF_PERIOD, "post_count" => "019"}]})

      assert_equal({(Time.utc(2026)...Time.utc(2026, 1, 2)) => 19}, Post.count_by_period("ruby", client: @client))
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
      usage = PostUsage.new({"daily_project_usage" => {"usage" => [{"usage" => "1"}]}})

      assert_equal "X::PostUsage#daily cannot be read from nil", assert_raises(InvalidAttribute) { usage.daily }.message
      assert_raises(InvalidAttribute) { PostUsage.new({"daily_project_usage" => {"usage" => [{"date" => 1, "usage" => "1"}]}}).daily }
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
