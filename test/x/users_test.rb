require_relative "../test_helper"

module X
  class UsersTest < Minitest::Test
    cover Users

    BASE_URL = "https://api.twitter.com/2/"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
      @user_data = {"data" => {"id" => "123", "name" => "Test", "username" => "test"}}.freeze
      @users_data = {"data" => [{"id" => "123", "name" => "Test", "username" => "test"}]}.freeze
      @headers = {"Content-Type" => "application/json"}
    end

    def test_user
      stub_request(:get, "#{BASE_URL}users/123")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user("123")

      assert_equal @user_data, result
    end

    def test_user_with_user_fields
      stub_request(:get, "#{BASE_URL}users/123?user.fields=created_at,description")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user("123", user_fields: %w[created_at description])

      assert_equal @user_data, result
    end

    def test_user_with_expansions
      stub_request(:get, "#{BASE_URL}users/123?expansions=pinned_tweet_id")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user("123", expansions: ["pinned_tweet_id"])

      assert_equal @user_data, result
    end

    def test_user_with_tweet_fields
      stub_request(:get, "#{BASE_URL}users/123?tweet.fields=created_at,text")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user("123", tweet_fields: %w[created_at text])

      assert_equal @user_data, result
    end

    def test_user_with_all_fields
      stub_request(:get, "#{BASE_URL}users/123?user.fields=created_at&expansions=pinned_tweet_id&tweet.fields=text")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user("123", user_fields: ["created_at"], expansions: ["pinned_tweet_id"],
        tweet_fields: ["text"])

      assert_equal @user_data, result
    end

    def test_user_with_string_fields
      stub_request(:get, "#{BASE_URL}users/123?user.fields=created_at")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user("123", user_fields: "created_at")

      assert_equal @user_data, result
    end

    def test_users
      stub_request(:get, "#{BASE_URL}users?ids=123,456")
        .to_return(body: @users_data.to_json, headers: @headers)

      result = @client.users(ids: %w[123 456])

      assert_equal @users_data, result
    end

    def test_users_with_user_fields
      stub_request(:get, "#{BASE_URL}users?user.fields=created_at,description&ids=123,456")
        .to_return(body: @users_data.to_json, headers: @headers)

      result = @client.users(ids: %w[123 456], user_fields: %w[created_at description])

      assert_equal @users_data, result
    end

    def test_users_with_single_id
      stub_request(:get, "#{BASE_URL}users?ids=123")
        .to_return(body: @users_data.to_json, headers: @headers)

      result = @client.users(ids: "123")

      assert_equal @users_data, result
    end

    def test_user_by_username
      stub_request(:get, "#{BASE_URL}users/by/username/sferik")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user_by_username("sferik")

      assert_equal @user_data, result
    end

    def test_user_by_username_with_user_fields
      stub_request(:get, "#{BASE_URL}users/by/username/sferik?user.fields=created_at,public_metrics")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.user_by_username("sferik", user_fields: %w[created_at public_metrics])

      assert_equal @user_data, result
    end

    def test_users_by_usernames
      stub_request(:get, "#{BASE_URL}users/by?usernames=sferik,xdevelopers")
        .to_return(body: @users_data.to_json, headers: @headers)

      result = @client.users_by_usernames(usernames: %w[sferik xdevelopers])

      assert_equal @users_data, result
    end

    def test_users_by_usernames_with_user_fields
      stub_request(:get, "#{BASE_URL}users/by?user.fields=created_at&usernames=sferik,xdevelopers")
        .to_return(body: @users_data.to_json, headers: @headers)

      result = @client.users_by_usernames(usernames: %w[sferik xdevelopers], user_fields: ["created_at"])

      assert_equal @users_data, result
    end

    def test_users_by_usernames_with_single_username
      stub_request(:get, "#{BASE_URL}users/by?usernames=sferik")
        .to_return(body: @users_data.to_json, headers: @headers)

      result = @client.users_by_usernames(usernames: "sferik")

      assert_equal @users_data, result
    end

    def test_me
      stub_request(:get, "#{BASE_URL}users/me")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.me

      assert_equal @user_data, result
    end

    def test_me_with_user_fields
      stub_request(:get, "#{BASE_URL}users/me?user.fields=created_at,description,public_metrics")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.me(user_fields: %w[created_at description public_metrics])

      assert_equal @user_data, result
    end

    def test_me_with_all_fields
      stub_request(:get, "#{BASE_URL}users/me?user.fields=created_at&expansions=pinned_tweet_id&tweet.fields=text")
        .to_return(body: @user_data.to_json, headers: @headers)

      result = @client.me(user_fields: ["created_at"], expansions: ["pinned_tweet_id"],
        tweet_fields: ["text"])

      assert_equal @user_data, result
    end
  end
end
