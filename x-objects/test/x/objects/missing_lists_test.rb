# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A list the response omitted reads as empty, as a list of references does, rather than nil
  class MissingListsTest < Minitest::Test
    cover Objects.const_get(:Attributes)
    cover Post

    LISTS = {
      Post => %i[edit_history_post_ids urls context_annotations referenced_posts media polls],
      Space => %i[host_ids speaker_ids invited_user_ids topic_ids hosts speakers invited_users],
      DirectMessage => %i[participant_ids referenced_posts participants media],
      User => %i[connection_status],
      Poll => %i[options],
      Place => %i[contained_within],
      Media => %i[variants]
    }.freeze

    def test_every_list_the_response_omitted_reads_as_empty_and_frozen
      LISTS.each do |klass, names|
        resource = klass.new({klass.__send__(:id_key) => klass.equal?(Media) ? "3_1" : "1"})
        names.each do |name|
          assert_empty resource.public_send(name), "Expected #{klass}##{name} to be empty"
          assert_predicate resource.public_send(name), :frozen?, "Expected #{klass}##{name} to be frozen"
        end
      end
    end

    def test_a_list_of_identifiers_the_response_holds_reads_as_integers_frozen
      host_ids = Space.new({"id" => "a", "host_ids" => %w[1 2]}).host_ids

      assert_equal [1, 2], host_ids
      assert_predicate host_ids, :frozen?
    end

    def test_a_list_the_response_holds_reads_as_it_is
      options = [{"position" => 1, "label" => "Yes"}]

      assert_equal options, Poll.new({"id" => "1", "options" => options}).options
    end
  end
end
