# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A cursor, and a response's record of what it asked for, keep frozen copies of the parameters they were given, so
  # a caller that changes its own Strings afterwards changes neither the pages a cursor asks for nor what is hydrated
  class ParamsCopiedTest < Minitest::Test
    cover Cursor
    cover Resources.const_get(:Includes)

    def test_a_cursor_asks_for_its_later_pages_with_the_query_it_was_given
      client = FakeClient.new.stub(:get, "tweets/search/recent", lambda { |query, _|
        query["pagination_token"] ? {"data" => [{"id" => "2"}]} : {"data" => [{"id" => "1"}], "meta" => {"next_token" => "p2"}}
      })
      query = +"ruby"
      cursor = Post.search(query, client:)
      cursor.page(0)
      query.replace("python")
      cursor.page(1)

      assert_equal %w[ruby ruby], client.queries.map { |sent| sent.fetch("query") }
    end

    def test_media_a_lookup_included_with_fewer_fields_stays_unhydrated_when_the_caller_changes_the_fields_after
      fields = +"media_key,type"
      client = FakeClient.new.stub(:get, "tweets/1", {"data" => {"id" => "1", "attachments" => {"media_keys" => ["3_1"]}},
                                                      "includes" => {"media" => [{"media_key" => "3_1", "type" => "photo"}]}})
      post = Post.find(1, client:, "media.fields": fields)
      fields.replace(Media::FIELDS.join(","))

      refute_predicate post.media.first, :hydrated?
    end
  end
end
