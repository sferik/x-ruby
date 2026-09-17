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
      assert_equal ["media", :media_keys, "media.fields"], [Media.endpoint, Media.batch_key, Media.fields_key]
      assert_equal({"media.fields" => Media::FIELDS}, Media.default_params)
    end

    def test_other_resources_are_looked_up_in_batches_by_ids
      assert_equal [:ids, :ids], [User.batch_key, Space.batch_key]
    end

    def test_find_looks_media_up_by_media_key_with_every_field
      client = FakeClient.new
      client.stub(:get, "media/3_1", {"data" => {"media_key" => "3_1", "type" => "photo", "url" => "https://pbs.twimg.com/media/1.jpg"}})
      media = Media.find("3_1", client:)

      assert_equal ["3_1", "https://pbs.twimg.com/media/1.jpg", true], [media.id, media.url, media.hydrated?]
      assert_equal({"media.fields" => Media::FIELDS.join(",")}, client.queries.first)
    end

    def test_find_bang_raises_for_media_that_is_not_found
      client = FakeClient.new
      client.stub(:get, "media/3_9", {"errors" => [{"title" => "Not Found Error", "detail" => "Could not find media with media_key: [3_9]."}]})

      assert_raises(ResourceNotFound) { Media.find!("3_9", client:) }
    end

    def test_find_all_looks_media_up_by_media_keys
      client = FakeClient.new
      client.stub(:get, "media", {"data" => [{"media_key" => "3_1"}, {"media_key" => "7_2"}]})

      assert_equal %w[3_1 7_2], Media.find_all(%w[3_1 7_2], client:).map(&:id)
      assert_equal "3_1,7_2", client.queries.first["media_keys"]
      refute_includes client.queries.first, "ids"
    end

    def test_the_media_of_a_post_hydrates_to_the_full_media
      client = FakeClient.new
      client.stub(:get, "media/3_1", {"data" => {"media_key" => "3_1", "alt_text" => "A cat"}})
      post = Post.new({"id" => "1", "attachments" => {"media_keys" => ["3_1"]}}, client:,
        includes: Objects::Includes.new({"media" => [{"media_key" => "3_1", "type" => "photo"}]}))
      media = post.media.first

      assert_equal [false, nil, "A cat"], [media.hydrated?, media.alt_text, media.hydrate.alt_text]
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
