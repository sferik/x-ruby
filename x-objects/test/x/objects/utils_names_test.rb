# frozen_string_literal: true

require_relative "../../test_helper"

module X
  module Objects
    class UtilsNamesTest < Minitest::Test
      cover Utils

      def test_username_strips_a_leading_at_sign
        assert_equal "sferik", Utils.username("@sferik")
        assert_equal "sferik", Utils.username("sferik")
        assert_equal "s@ferik", Utils.username("s@ferik")
        assert_equal "1", Utils.username(1)
      end

      def test_media_id_of
        assert_equal "3", Utils.media_id_of({"id" => "3", "media_key" => "3_3"})
        assert_equal "3", Utils.media_id_of({"id" => 3})
        assert_equal "3", Utils.media_id_of(Class.new(Hash).new.merge!("id" => "3"))
        assert_equal "3", Utils.media_id_of(3)
        assert_equal "3", Utils.media_id_of("3")
      end

      def test_media_id_of_uploaded_media_that_is_no_hash
        uploaded = Struct.new(:attrs) { def fetch(key) = attrs.fetch(key) }

        assert_equal "3", Utils.media_id_of(uploaded.new({"id" => "3"}))
        assert_raises(KeyError) { Utils.media_id_of(uploaded.new({"media_key" => "3_3"})) }
      end

      def test_media_id_of_media
        assert_equal "1880028106020515840", Utils.media_id_of(Media.new({"media_key" => "3_1880028106020515840", "type" => "photo"}))
        assert_equal "7", Utils.media_id_of(Struct.new(:media_key).new("13_7"))
      end

      def test_media_id_of_something_that_is_not_media
        [Object.new, Struct.new(:media_key).new(nil), Struct.new(:media_key).new("3_"), Struct.new(:media_key).new("x3_7"), :media].each do |value|
          error = assert_raises(ArgumentError, value.inspect) { Utils.media_id_of(value) }

          assert_equal "media is what an upload returned, media such as X::Media, or a media identifier, not #{value.inspect}", error.message
        end
      end

      def test_media_ids_of_many
        assert_equal %w[3 4 5], Utils.media_ids_of([{"id" => 3}, "4", 5])
        assert_empty Utils.media_ids_of([])
      end

      def test_media_ids_of_an_array_subclass
        assert_equal %w[3 4], Utils.media_ids_of(Class.new(Array).new(%w[3 4]))
      end

      def test_media_ids_of_one
        assert_equal %w[3], Utils.media_ids_of({"id" => "3"})
        assert_equal %w[4], Utils.media_ids_of("4")
        assert_equal %w[5], Utils.media_ids_of(5)
      end

      def test_media_id_of_a_response_without_an_id
        assert_raises(KeyError) { Utils.media_id_of({"media_key" => "3_3"}) }
      end

      def test_authenticator_of_a_client_with_one
        authenticator = Object.new
        client = Struct.new(:authenticator).new(authenticator)

        assert_same authenticator, Utils.authenticator_of(client)
      end

      def test_authenticator_of_a_client_without_one
        assert_nil Utils.authenticator_of(Object.new)
      end
    end
  end
end
