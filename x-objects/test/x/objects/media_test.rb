require_relative "../../test_helper"

module X
  class MediaTest < Minitest::Test
    cover Media

    def setup
      @media = Media.new({"media_key" => "3_1", "type" => "video", "url" => "https://pbs.twimg.com/1.jpg",
                          "preview_image_url" => "https://pbs.twimg.com/p.jpg", "alt_text" => "alt", "duration_ms" => 1000,
                          "height" => 720, "width" => 1280, "variants" => [{"bit_rate" => 1}],
                          "public_metrics" => {"view_count" => 42}})
    end

    def test_class_configuration
      assert_equal "media_key", Media.id_key
      assert_equal "media", Media.includes_key
      assert_nil Media.endpoint
      refute_predicate Media, :hydratable?
    end

    def test_attributes
      assert_equal "3_1", @media.media_key
      assert_equal "3_1", @media.id
      assert_equal "video", @media.type
      assert_equal "https://pbs.twimg.com/1.jpg", @media.url
      assert_equal "https://pbs.twimg.com/p.jpg", @media.preview_image_url
    end

    def test_more_attributes
      assert_equal "alt", @media.alt_text
      assert_equal 1000, @media.duration_ms
      assert_equal 720, @media.height
      assert_equal 1280, @media.width
      assert_equal [{"bit_rate" => 1}], @media.variants
    end

    def test_metrics
      assert_equal({"view_count" => 42}, @media.public_metrics)
      assert_equal 42, @media.view_count
    end
  end
end
