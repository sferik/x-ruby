# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class MediaUploadedTest < Minitest::Test
    cover Media

    KEY = "3_1880028106020515840"

    def setup
      @uploaded = Struct.new(:id, :media_key).new(1_880_028_106_020_515_840, KEY)
      @client = FakeClient.new
    end

    def test_find_bang_names_the_media_key_of_what_an_upload_returned
      @client.stub(:get, "media/#{KEY}", {"errors" => [{"title" => "Not Found Error"}]})
      error = assert_raises(MissingResource) { Media.find!(@uploaded, client: @client) }

      assert_equal "Could not find X::Media #{KEY}: Not Found Error", error.message
    end

    def test_find_bang_looks_up_what_an_upload_returned_with_the_params_given
      @client.stub(:get, "media/#{KEY}", {"data" => {"media_key" => KEY, "url" => "https://pbs.twimg.com/media/1.jpg"}})
      media = Media.find!(@uploaded, client: @client, "media.fields": "url")

      assert_equal [KEY, false], [media.id, media.hydrated?]
      assert_equal [{"media.fields" => "url"}], @client.queries
    end

    def test_from_id_refers_to_what_an_upload_returned_by_its_media_key
      batch = Objects::Batch.new(Media, [KEY], client: @client)
      stub = Media.from_id(@uploaded, client: @client, batch:)

      assert_equal [KEY, false], [stub.id, stub.hydrated?]
      assert_same batch, stub.instance_variable_get(:@batch)
    end

    def test_from_id_refers_to_media_by_its_media_key
      assert_equal "3_1", Media.from_id(Media.new({"media_key" => "3_1"})).id
    end

    def test_a_stub_of_what_an_upload_returned_hydrates_to_the_media
      @client.stub(:get, "media/#{KEY}", {"data" => {"media_key" => KEY, "url" => "https://pbs.twimg.com/media/1.jpg"}})

      assert_equal "https://pbs.twimg.com/media/1.jpg", Media.from_id(@uploaded, client: @client).hydrate.url
    end
  end
end
