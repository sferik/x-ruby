# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # Every count a resource reads is an Integer, as its signature says, so a count the response gives as a string of
  # digits is read as the number it is, and one that is no whole number raises InvalidAttribute where it is read
  class CountAttributesTest < Minitest::Test
    cover Resources.const_get(:Attributes)
    cover Page

    COUNTS = {
      Community => {member_count: %w[member_count]},
      List => {follower_count: %w[follower_count], member_count: %w[member_count]},
      Media => {duration_ms: %w[duration_ms], height: %w[height], width: %w[width], view_count: %w[public_metrics view_count]},
      Poll => {duration_minutes: %w[duration_minutes]},
      Post => {repost_count: %w[public_metrics repost_count], reply_count: %w[public_metrics reply_count],
               like_count: %w[public_metrics like_count], quote_count: %w[public_metrics quote_count],
               bookmark_count: %w[public_metrics bookmark_count], impression_count: %w[public_metrics impression_count]},
      Space => {participant_count: %w[participant_count], subscriber_count: %w[subscriber_count]},
      User => {verified_followers_count: %w[verified_followers_count], subscriber_count: %w[subscriber_count],
               followers_count: %w[public_metrics followers_count], following_count: %w[public_metrics following_count],
               post_count: %w[public_metrics post_count], listed_count: %w[public_metrics listed_count],
               like_count: %w[public_metrics like_count], media_count: %w[public_metrics media_count]}
    }.freeze

    def test_a_count_is_read_as_an_integer
      each_count do |klass, name, path|
        assert_equal 12, resource(klass, path, 12).public_send(name), "#{klass}##{name}"
        assert_equal 12, resource(klass, path, "12").public_send(name), "#{klass}##{name}"
        assert_nil resource(klass, path, nil).public_send(name), "#{klass}##{name}"
      end
    end

    def test_a_count_that_is_no_whole_number_raises
      each_count do |klass, name, path|
        [1.5, "many", true, -3, "-3", "+3", "1_000", " 12\n", "12\n"].each do |value|
          error = assert_raises(InvalidAttribute, "#{klass}##{name}") { resource(klass, path, value).public_send(name) }

          assert_equal "#{klass}##{name} cannot be read from #{value.inspect}", error.message
        end
      end
    end

    def test_the_result_count_of_a_page_is_read_as_an_integer
      assert_equal [3, 3, nil], [{"result_count" => 3}, {"result_count" => "3"}, {}].map { |meta| Page.new([], meta:).result_count }
      error = assert_raises(InvalidAttribute) { Page.new([], meta: {"result_count" => "3.0"}).result_count }

      assert_equal "X::Page#result_count cannot be read from \"3.0\"", error.message
    end

    private

    def each_count(&)
      COUNTS.each { |klass, counts| counts.each { |name, path| yield klass, name, path } }
    end

    def resource(klass, path, value)
      attrs = path[..-2].reverse.reduce({path.last => value}) { |inner, key| {key => inner} }
      klass.new(attrs.merge(klass.eql?(Media) ? {"media_key" => "3_1"} : {"id" => "1"}))
    end
  end
end
