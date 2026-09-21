# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class PatternMatchingTest < Minitest::Test
    cover Objects::Identity
    cover Objects::Attributes
    cover Resource
    cover Post
    cover User

    def setup
      @user = User.new({"id" => "7505382", "username" => "sferik", "created_at" => "2007-07-16T12:59:01.000Z"})
      @post = Post.new({"id" => "1", "public_metrics" => {"like_count" => 100}})
    end

    def test_a_resource_matches_no_array_pattern
      matched = case @user
      in [7505382] then :array
      in X::User then :resource
      end

      assert_equal :resource, matched
      refute_respond_to @user, :deconstruct
    end

    def test_a_resource_matches_a_hash_pattern_as_its_readers_read_it
      matched = case @user
      in {username: "sferik", id: Integer => id, created_at: Time} then id
      end

      assert_equal 7505382, matched
    end

    def test_a_pattern_reads_an_attribute_the_api_nests
      matched = case @post
      in {like_count: 50..} then :popular
      end

      assert_equal :popular, matched
    end

    def test_a_pattern_asking_for_every_attribute_reads_every_attribute
      matched = case @user
      in {**attributes} then attributes
      end

      assert_equal({id: 7505382, username: "sferik", created_at: Time.utc(2007, 7, 16, 12, 59, 1)}, matched.compact)
      assert_equal User.attribute_names.size, matched.size
    end

    def test_deconstruct_keys_reads_the_attributes_it_is_asked_for
      assert_equal({username: "sferik"}, @user.deconstruct_keys([:username]))
      assert_empty @user.deconstruct_keys([:nothing_of_the_sort])
    end

    def test_a_pattern_reads_an_attribute_by_another_name_it_is_read_by
      post = Post.new({"id" => "1", "public_metrics" => {"repost_count" => 5}, "note_post" => {"text" => "long"}})
      user = User.new({"id" => "1", "pinned_post_id" => "9", "public_metrics" => {"post_count" => 3}})
      message = DirectMessage.new({"id" => "1", "dm_conversation_id" => "9-8"})

      matched = case post
      in {retweet_count: 5, note_tweet: Hash => note, repost_count: 5} then note
      end

      assert_equal({"text" => "long"}, matched)
      assert_equal({tweet_count: 3, pinned_tweet_id: 9}, user.deconstruct_keys(%i[tweet_count pinned_tweet_id pinned_tweet]))
      assert_equal({conversation_id: "9-8"}, message.deconstruct_keys([:conversation_id]))
    end

    def test_a_pattern_asking_for_every_attribute_reads_each_once_by_the_name_it_is_declared_by
      refute_includes @post.deconstruct_keys(nil), :retweet_count
      assert_equal Post.attribute_names, @post.deconstruct_keys(nil).keys
    end

    def test_declaring_an_alias_records_its_name_after_the_ones_it_inherits
      klass = Class.new(User) { attribute_alias :handle, :username }

      assert_equal %i[tweet_count pinned_tweet_id most_recent_tweet_id], User.attribute_aliases
      assert_equal User.attribute_aliases + [:handle], klass.attribute_aliases
      assert_equal "sferik", klass.new({"id" => "1", "username" => "sferik"}).handle
      assert_equal %i[retweet_count edit_history_tweet_ids note_tweet referenced_tweets], Post.attribute_aliases
      assert_equal %i[conversation_id referenced_tweets], DirectMessage.attribute_aliases
    end

    def test_a_resource_without_aliases_declares_none
      assert_empty Resource.attribute_aliases
      assert_empty Class.new { extend Objects::Attributes }.attribute_aliases
      assert_empty List.attribute_aliases
    end

    def test_declaring_an_attribute_records_its_name_after_the_ones_it_inherits
      klass = Class.new(User) { attribute :nickname }

      assert_equal User.attribute_names + [:nickname], klass.attribute_names
      refute_includes User.attribute_names, :nickname
      assert_equal [:id], Class.new { extend Objects::Attributes }.attribute_names
    end

    def test_every_resource_declares_its_identifier_and_its_own_attributes
      assert_equal [:id], Resource.attribute_names
      assert_equal :id, User.attribute_names.first
      assert_includes User.attribute_names, :username
      refute_includes Post.attribute_names, :username
    end
  end
end
