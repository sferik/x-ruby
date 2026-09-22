# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class UploadedMediaTest < Minitest::Test
    cover UploadedMedia

    ATTRS = {"id" => "1880028106020515840", "media_key" => "3_1880028106020515840", "size" => 1024, "expires_after_secs" => 86_400}.freeze
    READ_ATTRS = ATTRS.merge("id" => 1_880_028_106_020_515_840).freeze

    def setup
      @media = UploadedMedia.new(ATTRS)
    end

    def media_in(state, **info)
      UploadedMedia.new(ATTRS.merge("processing_info" => {"state" => state, **info.transform_keys(&:to_s)}))
    end

    def test_reads_the_identifier_as_an_integer_and_the_rest_as_given
      assert_equal [1_880_028_106_020_515_840, "3_1880028106020515840", 1024], [@media.id, @media.media_key, @media.bytesize]
    end

    def test_reads_an_identifier_held_as_an_integer
      assert_equal 1_880_028_106_020_515_840, UploadedMedia.new({"id" => 1_880_028_106_020_515_840}).id
    end

    def test_the_bytes_of_the_media_are_its_bytesize_and_its_size_is_the_hash_it_reads_as
      assert_equal 1024, @media["size"]
      refute_respond_to @media, :size
    end

    def test_what_a_response_leaves_out_is_nil
      media = UploadedMedia.new({"id" => "7"})

      assert_equal [nil, nil], [media.media_key, media.bytesize]
    end

    def test_an_identifier_that_is_not_a_decimal_number_raises
      assert_raises(ArgumentError) { UploadedMedia.new({"id" => "0x10"}).id }
    end

    def test_expires_at_counts_from_when_the_response_arrived
      now = Time.at(1_789_000_000)
      media = Time.stub(:now, now) { UploadedMedia.new(ATTRS) }

      assert_equal now + 86_400, media.expires_at
      assert_predicate media.expires_at, :utc?
      assert_nil UploadedMedia.new({"id" => "7"}).expires_at
    end

    def test_media_that_x_does_not_process_is_ready
      assert_equal [nil, nil, nil], [@media.processing_info, @media.state, @media.check_after_secs]
      assert_equal [false, false, true], [@media.processing?, @media.failed?, @media.ready?]
    end

    def test_media_with_null_processing_information_is_ready
      media = UploadedMedia.new({"id" => "7", "processing_info" => nil})

      assert_equal [false, false, true], [media.processing?, media.failed?, media.ready?]
    end

    def test_media_that_is_pending_or_in_progress_is_processing
      %w[pending in_progress].each do |state|
        media = media_in(state, check_after_secs: 5)

        assert_equal [state, 5, {"state" => state, "check_after_secs" => 5}], [media.state, media.check_after_secs, media.processing_info]
        assert_equal [true, false, false], [media.processing?, media.failed?, media.ready?]
      end
    end

    def test_media_in_a_state_without_a_name_is_processing
      media = UploadedMedia.new({"id" => "7", "processing_info" => {}})

      assert_equal [true, false, false], [media.processing?, media.failed?, media.ready?]
    end

    def test_media_that_succeeded_is_ready_and_media_that_failed_is_not
      assert_equal [false, false, true], media_in("succeeded").then { |media| [media.processing?, media.failed?, media.ready?] }
      assert_equal [false, true, false], media_in("failed").then { |media| [media.processing?, media.failed?, media.ready?] }
    end

    def test_reads_as_the_hash_it_was_built_from
      media = media_in("succeeded")

      assert_equal [1_880_028_106_020_515_840, nil, "succeeded"], [media["id"], media["missing"], media.dig("processing_info", "state")]
      assert_equal [true, false], [media.key?("processing_info"), media.key?("missing")]
      assert_equal READ_ATTRS, @media.to_h
      assert_same @media.attrs, @media.to_h
    end

    def test_holds_a_copy_of_the_attributes_it_was_given
      attrs = {"id" => +"7", "processing_info" => {"state" => +"pending"}, "variants" => [+"a"]}
      media = UploadedMedia.new(attrs)
      attrs["id"] << "8"
      attrs["processing_info"]["state"] << "!"
      attrs["variants"] << "b"

      assert_equal [7, "pending", ["a"]], [media.id, media.state, media["variants"]]
    end

    def test_is_frozen_with_all_that_it_holds
      media = UploadedMedia.new({"id" => +"7", "processing_info" => {"state" => +"pending"}, "variants" => [+"a"]})
      held = [media.attrs, media["id"], media.processing_info, media.state, media["variants"], media["variants"].first]

      assert_predicate media, :frozen?
      assert held.all?(&:frozen?)
    end

    def test_media_with_the_same_attributes_is_equal
      same = UploadedMedia.new(ATTRS.dup)

      assert_equal [true, true, true], [@media == same, @media.eql?(same), @media.hash.eql?(same.hash)]
      assert_equal 1, [@media, same].uniq.size
    end

    def test_media_is_equal_to_nothing_else
      other = UploadedMedia.new(ATTRS.merge("size" => 1))

      assert_equal [false, false, false], [@media == other, @media == ATTRS, @media == Class.new(UploadedMedia).new(ATTRS)]
      refute_equal @media.hash, other.hash
      refute_equal @media.hash, Class.new(UploadedMedia).new(ATTRS).hash
    end

    def test_from_builds_media_from_data_and_nothing_from_none
      assert_equal @media, UploadedMedia.from(ATTRS)
      assert_nil UploadedMedia.from(nil)
    end

    def test_inspect_of_media_without_an_identifier_raises_nothing
      assert_equal "#<X::UploadedMedia id=nil media_key=nil state=nil>", UploadedMedia.new({}).inspect
    end

    def test_inspect_names_the_identifier_the_media_key_and_the_state
      assert_equal '#<X::UploadedMedia id=1880028106020515840 media_key="3_1880028106020515840" state=nil>', @media.inspect
      assert_equal '#<X::UploadedMedia id=1880028106020515840 media_key="3_1880028106020515840" state="failed">', media_in("failed").inspect
    end
  end

  class UploadedMediaHashTest < Minitest::Test
    cover UploadedMedia

    ATTRS = UploadedMediaTest::ATTRS
    READ_ATTRS = UploadedMediaTest::READ_ATTRS

    def setup
      @media = UploadedMedia.new(ATTRS)
    end

    def test_fetch_raises_or_falls_back_as_a_hash_does
      assert_equal 1_880_028_106_020_515_840, @media.fetch("id")
      assert_equal 1_880_028_106_020_515_840, @media.fetch("id") { flunk "unexpected yield" }
      assert_equal "missing!", @media.fetch("missing") { |key| "#{key}!" }
      assert_raises(KeyError) { @media.fetch("missing") }
    end

    def test_fetch_returns_the_default_given_for_what_a_response_holds_none_of
      assert_equal [nil, "none", 1024], [@media.fetch("processing_info", nil), @media.fetch("missing", "none"), @media.fetch("size", "none")]
    end

    def test_fetch_takes_the_arguments_a_hash_takes_and_no_more
      error = assert_raises(ArgumentError) { @media.fetch("id", "none", "extra") }

      assert_equal "wrong number of arguments (given 3, expected 1..2)", error.message
    end

    def test_media_is_written_into_json_as_the_attributes_it_reads_as
      assert_equal READ_ATTRS, @media.as_json
      assert_equal READ_ATTRS.to_json, @media.to_json
      assert_equal({"media_ids" => [READ_ATTRS]}, JSON.parse(JSON.generate({media_ids: [@media]})))
    end

    def test_media_is_written_with_the_state_of_the_json_generated_around_it
      assert_equal JSON.pretty_generate({"media" => READ_ATTRS}), JSON.pretty_generate({"media" => @media})
    end
  end
end
