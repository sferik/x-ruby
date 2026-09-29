# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class TrendTest < Minitest::Test
    cover Trend
    cover PersonalizedTrend
    cover Objects::API::Lookups::Trends

    TRENDS = [{"trend_name" => "#ruby", "tweet_count" => 1234}, {"trend_name" => "Rails"}].freeze
    PERSONALIZED = [{"trend_name" => "#ruby", "category" => "Technology", "post_count" => "12.3K posts", "trending_since" => "Trending now"}].freeze

    def setup
      @client = FakeClient.new
      @client.stub(:get, "trends/by/woeid/1", {"data" => TRENDS})
      @client.stub(:get, "users/personalized_trends", {"data" => PERSONALIZED})
    end

    def test_the_trends_of_a_place_ask_for_every_field_and_the_most_trends
      trends = @client.trends(1)

      assert_equal [["#ruby", 1234], ["Rails", nil]], trends.map { |trend| [trend.name, trend.post_count] }
      assert_equal [{"trend.fields" => "trend_name,tweet_count", "max_trends" => "50"}], @client.queries
      assert_predicate trends, :frozen?
    end

    def test_the_trends_of_a_place_take_parameters
      @client.trends("1", max_trends: 10)

      assert_equal [{"trend.fields" => "trend_name,tweet_count", "max_trends" => "10"}], @client.queries
    end

    def test_the_trends_of_a_place_are_read_as_the_app
      app = FakeClient.new.stub(:get, "trends/by/woeid/23424977", {"data" => TRENDS})
      client = Struct.new(:app_only).new(app)

      assert_equal ["#ruby", "Rails"], Trend.at(23_424_977, client:).map(&:name)
      assert_equal 1, app.requests.size
    end

    def test_a_place_without_trends
      @client.stub(:get, "trends/by/woeid/2", {"errors" => [{"title" => "Not Found Error"}]})

      @client.stub(:get, "trends/by/woeid/3", nil)

      assert_empty Trend.at(2, client: @client)
      assert_predicate Trend.at(2, client: @client), :frozen?
      assert_empty Trend.at(3, client: @client)
    end

    def test_a_woeid_that_is_not_one_is_refused_before_a_request
      ["abc", "1/2", "1\n", -1, 1.0, :"1", nil, "", Trend].each do |woeid|
        error = assert_raises(ArgumentError) { @client.trends(woeid) }

        assert_equal "#{woeid.inspect} is not a WOEID: pass an Integer, or a String of digits", error.message
      end
      assert_empty @client.requests
    end

    def test_trends_that_cannot_be_read
      @client.stub(:get, "trends/by/woeid/1", {"data" => {"trend_name" => "#ruby"}})

      assert_equal "X::Trend.at cannot be read from #{{"trend_name" => "#ruby"}.inspect}", assert_raises(InvalidAttribute) { Trend.at(1, client: @client) }.message
      assert_equal 'X::Trend#post_count cannot be read from "many"', assert_raises(InvalidAttribute) { Trend.new({"tweet_count" => "many"}).post_count }.message
    end

    def test_a_trend
      trend = Trend.new({"trend_name" => +"#ruby", "tweet_count" => "1234"})

      assert_equal [1234, 1234], [trend.post_count, trend.tweet_count]
      assert_equal({"trend_name" => "#ruby", "tweet_count" => "1234"}, trend.to_h)
      assert_predicate trend, :frozen?
      assert_predicate trend.attrs["trend_name"], :frozen?
      assert_equal '{"trend_name":"#ruby","tweet_count":"1234"}', trend.to_json
    end

    def test_the_personalized_trends_ask_for_every_field
      trends = @client.personalized_trends

      assert_equal [["#ruby", "Technology", "12.3K posts", "Trending now"]], trends.map { |trend| [trend.name, trend.category, trend.post_count_text, trend.trending_since] }
      assert_equal [{"personalized_trend.fields" => "category,post_count,trend_name,trending_since"}], @client.queries
      assert_predicate trends, :frozen?
    end

    def test_the_personalized_trends_take_parameters_and_are_read_as_the_user
      @client.personalized_trends("personalized_trend.fields": "trend_name")

      assert_equal [{"personalized_trend.fields" => "trend_name"}], @client.queries
      assert_equal "users/personalized_trends", @client.paths.first
    end

    def test_personalized_trends_that_cannot_be_read
      @client.stub(:get, "users/personalized_trends", {"data" => "#ruby"})

      assert_equal 'X::PersonalizedTrend.all cannot be read from "#ruby"', assert_raises(InvalidAttribute) { PersonalizedTrend.all(client: @client) }.message
      @client.stub(:get, "users/personalized_trends", nil)

      assert_empty PersonalizedTrend.all(client: @client)
    end

    def test_a_trend_without_a_name
      assert_nil Trend.new({}).name
      assert_nil PersonalizedTrend.new({}).name
    end

    def test_a_personalized_trend
      trend = PersonalizedTrend.new({"trend_name" => +"#ruby"})

      assert_equal [nil, nil, nil], [trend.category, trend.post_count_text, trend.trending_since]
      assert_equal({"trend_name" => "#ruby"}, trend.to_h)
      assert_predicate trend, :frozen?
      assert_predicate trend.attrs["trend_name"], :frozen?
      assert_equal({"trend_name" => "#ruby"}, trend.as_json)
    end
  end
end
