# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # What a resource class reads of itself and of another to look resources up is private, and read with __send__
  class PrivateInternalsTest < Minitest::Test
    RESOURCE_METHODS = %i[endpoint endpoint! id_key id_type includes_key fields_key from_id_in_batch build fully_requested_by?
      batch_key lookup lookup_all client_for attribute_names attribute_aliases reference_keys referenced_ids].freeze

    def test_no_resource_class_reads_its_lookups_publicly
      [Resource, User, Post, List, DirectMessage, Space, Community, Media, Poll, Place].each do |klass|
        RESOURCE_METHODS.each { |name| refute_respond_to klass, name, "Expected #{klass}.#{name} to be private" }
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
      assert_raises(NameError) { Cursor::DEFAULT_TOKEN_PARAM }
    end

    def test_the_trends_of_a_user_and_the_usage_name_their_endpoints_privately
      assert_raises(NameError) { PersonalizedTrend::ENDPOINT }
      assert_raises(NameError) { Usage::ENDPOINT }
    end
  end
end
