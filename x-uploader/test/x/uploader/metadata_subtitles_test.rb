# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/metadata"

module X
  class MetadataSubtitlesTest < Minitest::Test
    cover Uploader::Metadata
    cover Uploader.const_get(:Utils)

    SUBTITLES_URL = "https://api.x.com/2/media/subtitles"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_add_subtitles_raises_when_the_response_holds_no_metadata
      stub_request(:post, SUBTITLES_URL).to_return(headers: JSON_HEADERS, body: "{}")
      error = assert_raises(MissingMediaData) { Uploader::Metadata.add_subtitles(7, 8, "EN", client: @client) }

      assert_equal "The response that adds the metadata holds none", error.message
    end

    def test_add_subtitles
      stub_request(:post, SUBTITLES_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7", media_category: "TweetVideo"}}.to_json)
      video = UploadedMedia.new({"id" => "7"})

      assert_same video, Uploader::Metadata.add_subtitles(video, {"id" => "8"}, "en", client: @client, display_name: "English")
      assert_requested :post, SUBTITLES_URL,
        body: {id: "7", media_category: "TweetVideo", subtitles: {id: "8", language_code: "EN", display_name: "English"}}.to_json
    end

    def test_add_subtitles_is_sent_again_after_the_api_fails_to_answer_it
      @client = Client.new(max_retries: 1)
      stub_request(:post, SUBTITLES_URL).to_return({status: 503}, {headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json})

      build = Core::RetryHandler.method(:new)
      without_sleeping = ->(**options) { build.call(**options).tap { |handler| handler.define_singleton_method(:sleep) { |_seconds| nil } } }

      assert_equal 7, Core::RetryHandler.stub(:new, without_sleeping) { Uploader::Metadata.add_subtitles(7, 8, "EN", client: @client) }.id
      assert_requested :post, SUBTITLES_URL, times: 2
    end

    def test_add_subtitles_without_a_display_name
      stub_request(:post, SUBTITLES_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)

      assert_equal UploadedMedia.new({"id" => "7"}), Uploader::Metadata.add_subtitles(7, 8, "FR", client: @client)
      assert_requested :post, SUBTITLES_URL, body: {id: "7", media_category: "TweetVideo", subtitles: {id: "8", language_code: "FR"}}.to_json
    end

    def test_the_media_categories_of_the_subtitles_are_private
      assert_raises(NameError) { Uploader::Metadata::SUBTITLED_MEDIA_CATEGORY }
      refute Uploader::Metadata.const_defined?(:AMPLIFY_SUBTITLED_MEDIA_CATEGORY)
    end

    def test_add_subtitles_to_an_amplify_video
      stub_request(:post, SUBTITLES_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)
      Uploader::Metadata.add_subtitles(7, 8, "EN", client: @client, media_category: :amplify_video)

      assert_requested :post, SUBTITLES_URL, body: {id: "7", media_category: "AmplifyVideo", subtitles: {id: "8", language_code: "EN"}}.to_json
    end

    def test_add_subtitles_takes_the_category_the_video_was_uploaded_as_in_any_case
      stub_request(:post, SUBTITLES_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)
      {"TweetVideo" => [:tweet_video, "TWEET_VIDEO", "tweetVideo"], "AmplifyVideo" => [:amplify_video, "Amplify_Video", "AmplifyVideo"]}.each do |sent, given|
        given.each do |media_category|
          WebMock.reset_executed_requests!
          Uploader::Metadata.add_subtitles(7, 8, "EN", client: @client, media_category:)

          assert_requested :post, SUBTITLES_URL, body: {id: "7", media_category: sent, subtitles: {id: "8", language_code: "EN"}}.to_json
        end
      end
    end

    def test_add_subtitles_refuses_any_other_category_before_a_request
      error = assert_raises(ArgumentError) { Uploader::Metadata.add_subtitles(7, 8, "EN", client: @client, media_category: :tweet_image) }

      assert_equal "Invalid media_category: tweet_image. Valid values: tweet_video, amplify_video", error.message
      assert_not_requested :post, SUBTITLES_URL
    end
  end
end
