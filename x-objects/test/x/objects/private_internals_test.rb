# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # What a resource class reads of itself and of another to look resources up is private, and read with __send__
  class PrivateInternalsTest < Minitest::Test
    RESOURCE_METHODS = %i[endpoint endpoint! id_key id_type includes_key fields_key from_id_in_batch build fully_requested_by?
      hydratable? batchable? batch_key lookup lookup_all client_for attribute_names attribute_aliases].freeze

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
  end
end
