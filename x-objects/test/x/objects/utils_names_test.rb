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

      def test_media_id_of_a_response_without_an_id
        assert_raises(KeyError) { Utils.media_id_of({"media_key" => "3_3"}) }
      end
    end
  end
end
