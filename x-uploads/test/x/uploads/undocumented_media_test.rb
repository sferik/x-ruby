# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/media_upload"

module X
  # A response that holds media the API documents no such thing as, such as an identifier that is not one, processing
  # information of another type, or a body that is not an object, raises MissingMediaData, an X::Error, so that
  # rescuing X::Error catches every failure of an upload
  class UndocumentedMediaTest < Minitest::Test
    cover UploadedMedia
    cover Uploads::MediaUpload
    cover Uploads.const_get(:Utils)
    cover Uploads.const_get(:Chunks)

    BASE_URL = "https://api.x.com/2/media/upload"
    STATUS_URL = "#{BASE_URL}?command=STATUS&media_id=#{TEST_MEDIA_ID}".freeze

    def setup
      @client = Client.new
    end

    def answer(url, body, method: :post)
      stub_request(method, url).to_return(headers: {"Content-Type" => "application/json"}, body: body.to_json)
    end

    def media(**attrs) = {data: {id: TEST_MEDIA_ID, media_key: "7_#{TEST_MEDIA_ID}"}.merge(attrs)}

    def test_an_image_whose_response_holds_media_the_api_documents_no_such_thing_as_raises
      [{data: {id: "abc"}}, media(processing_info: "x"), media(processing_info: {state: 1}), 7, [1]].each do |body|
        answer(BASE_URL, body)

        assert_raises(MissingMediaData, body.inspect) { Uploads::MediaUpload.upload("test/sample_files/sample.png", client: @client) }
      end
    end

    def test_a_status_whose_processing_holds_a_wait_or_an_error_of_another_type_raises
      [{state: "pending", check_after_secs: true}, {state: "pending", check_after_secs: {}}, {state: "failed", error: "x"}].each do |info|
        answer(STATUS_URL, media(processing_info: info), method: :get)

        assert_raises(MissingMediaData, info.inspect) { Uploads::MediaUpload.await_processing(TEST_MEDIA_ID, client: @client) }
      end
    end

    def test_a_status_whose_wait_is_a_number_or_a_string_is_waited_for
      [1, "1", 0.5].each do |wait|
        stub_request(:get, STATUS_URL).to_return({headers: {"Content-Type" => "application/json"}, body: media(processing_info: {state: "pending", check_after_secs: wait}).to_json},
          {headers: {"Content-Type" => "application/json"}, body: media(processing_info: {state: "succeeded"}).to_json})

        assert_predicate on_fake_clock { Uploads::MediaUpload.await_processing(TEST_MEDIA_ID, client: @client) }, :ready?
      end
    end

    def test_an_initialize_response_that_is_not_an_object_raises
      answer("#{BASE_URL}/initialize", [1])

      assert_raises(MissingMediaData) { Uploads::MediaUpload.chunked_upload("test/sample_files/sample.mp4", client: @client, media_category: "tweet_video") }
    end
  end
end
