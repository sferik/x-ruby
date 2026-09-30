# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # What a resource class reads of itself and of another to look resources up is private, and read with __send__
  class PrivateInternalsTest < Minitest::Test
    RESOURCE_METHODS = %i[endpoint endpoint! id_key id_type includes_key fields_key from_id_in_batch build fully_requested_by?
      batch_key lookup lookup_all client_for attribute_names attribute_aliases reference_keys referenced_ids resource_built_from
      collection_built_from resource_from_response collection_from_response].freeze

    def test_no_resource_class_reads_its_lookups_publicly
      [Resource, User, Post, List, DirectMessage, Space, Community, Media, Poll, Place].each do |klass|
        RESOURCE_METHODS.each { |name| refute_respond_to klass, name, "Expected #{klass}.#{name} to be private" }
      end
    end

    def test_a_resource_class_builds_from_a_response_without_the_query_of_its_request
      [:resource_from_response, :collection_from_response].each do |name|
        refute_includes User.method(name).parameters, [:key, :query]
      end
    end

    def test_media_reads_the_key_of_media_privately
      refute_respond_to Media, :key_of
    end

    def test_a_cursor_is_built_privately
      refute_respond_to Cursor, :build
    end

    def test_a_cursor_reads_the_settings_it_pages_with_privately
      cursor = User.new({"id" => "1"}, client: FakeClient.new).followers

      refute_respond_to cursor, :token_param
      refute_respond_to cursor, :min_results
      refute_respond_to cursor, :app_only?
      assert_raises(NameError) { Cursor::DEFAULT_TOKEN_PARAM }
    end

    def test_the_trends_of_a_user_and_the_usage_name_their_endpoints_privately
      assert_raises(NameError) { PersonalizedTrend::ENDPOINT }
      assert_raises(NameError) { Usage::ENDPOINT }
    end

    def test_a_resource_and_a_page_name_the_format_marshal_writes_privately
      assert_raises(NameError) { Resource::MARSHAL_FORMAT }
      assert_raises(NameError) { User::MARSHAL_FORMAT }
      assert_raises(NameError) { Page::MARSHAL_FORMAT }
    end

    def test_a_post_names_the_types_of_its_references_privately
      assert_raises(NameError) { Post::REPLIED_TO }
      assert_raises(NameError) { Post::QUOTED }
      assert_raises(NameError) { Post::REPOSTED }
      assert_raises(NameError) { Post::RETWEETED }
    end

    def test_the_counts_of_posts_name_their_endpoints_and_granularity_privately
      assert_raises(NameError) { Objects::PostCounts::RECENT_ENDPOINT }
      assert_raises(NameError) { Objects::PostCounts::ALL_ENDPOINT }
      assert_raises(NameError) { Objects::PostCounts::DEFAULT_GRANULARITY }
    end

    def test_the_helpers_name_the_patterns_they_read_alone_privately
      assert_raises(NameError) { Objects::Utils::RAW_ID }
      assert_raises(NameError) { Objects::Utils::USERNAME }
      assert_raises(NameError) { Objects::DirectMessageConversations::CONVERSATION_ID }
    end

    def test_the_internals_of_a_resource_name_their_constants_privately
      assert_raises(NameError) { Objects::Memo::UNSET }
      assert_raises(NameError) { Objects::Includes::TWEET_KEYS }
      assert_raises(NameError) { Objects::Attributes::EMPTY_LIST }
    end
  end
end
