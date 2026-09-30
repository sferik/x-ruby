# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/metadata"

module X
  class MetadataTest < Minitest::Test
    cover Uploader::Metadata
    cover Uploader.const_get(:Utils)

    METADATA_URL = "https://api.x.com/2/media/metadata"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_add_alt_text_to_an_upload_response
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)

      assert_equal UploadedMedia.new({"id" => 7, "media_key" => "3_7"}), Uploader::Metadata.add_alt_text({"id" => 7, "media_key" => "3_7"}, "A cat", client: @client)
      assert_requested :post, METADATA_URL, body: {id: "7", metadata: {alt_text: {text: "A cat"}}}.to_json
    end

    def test_add_alt_text_to_a_media_identifier
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)

      assert_equal UploadedMedia.new({"id" => "7"}), Uploader::Metadata.add_alt_text(7, "A cat", client: @client)
      assert_requested :post, METADATA_URL, body: {id: "7", metadata: {alt_text: {text: "A cat"}}}.to_json
    end

    def test_add_alt_text_to_a_media_key
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)

      assert_equal UploadedMedia.new({"id" => "7"}), Uploader::Metadata.add_alt_text("3_7", "A cat", client: @client)
      assert_requested :post, METADATA_URL, body: {id: "7", metadata: {alt_text: {text: "A cat"}}}.to_json
    end

    def test_add_alt_text_returns_the_uploaded_media_it_was_given
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7", associated_metadata: {}}}.to_json)
      media = UploadedMedia.new({"id" => "7", "size" => 1024})

      assert_same media, Uploader::Metadata.add_alt_text(media, "A cat", client: @client)
    end

    def test_add_alt_text_to_media_that_has_a_media_key
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)
      media = Uploader::Metadata.add_alt_text(Struct.new(:media_key).new("3_7"), "A cat", client: @client)

      assert_equal UploadedMedia.new({"id" => "7", "media_key" => "3_7"}), media
      assert_requested :post, METADATA_URL, body: {id: "7", metadata: {alt_text: {text: "A cat"}}}.to_json
    end

    def test_add_alt_text_to_a_response_parsed_into_a_hash_subclass
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json)
      response = Class.new(Hash).new
      response["id"] = 7
      Uploader::Metadata.add_alt_text(response, "A cat", client: @client)

      assert_requested :post, METADATA_URL, body: {id: "7", metadata: {alt_text: {text: "A cat"}}}.to_json
    end

    def test_add_alt_text_is_sent_again_after_the_api_fails_to_answer_it
      @client = Client.new(max_retries: 1)
      stub_request(:post, METADATA_URL).to_return({status: 503}, {headers: JSON_HEADERS, body: {data: {id: "7"}}.to_json})

      build = Core::RetryHandler.method(:new)
      without_sleeping = ->(**options) { build.call(**options).tap { |handler| handler.define_singleton_method(:sleep) { |_seconds| nil } } }

      assert_equal 7, Core::RetryHandler.stub(:new, without_sleeping) { Uploader::Metadata.add_alt_text(7, "A cat", client: @client) }.id
      assert_requested :post, METADATA_URL, times: 2
    end

    def test_add_alt_text_rejects_alt_text_the_api_would_refuse_before_a_request
      error = assert_raises(ArgumentError) { Uploader::Metadata.add_alt_text(7, "A" * 1001, client: @client) }

      assert_equal "alt_text must be 1 to 1000 characters, not 1001", error.message
      assert_raises(ArgumentError) { Uploader::Metadata.add_alt_text(7, "", client: @client) }
      assert_not_requested :post, METADATA_URL
    end

    def test_add_alt_text_raises_when_the_response_holds_no_metadata
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: "{}")
      error = assert_raises(MissingMediaData) { Uploader::Metadata.add_alt_text(7, "A cat", client: @client) }

      assert_equal "The response that adds the metadata holds none", error.message
    end

    def test_add_alt_text_names_the_problems_a_response_holds_in_place_of_metadata
      stub_request(:post, METADATA_URL).to_return(headers: JSON_HEADERS, body: {errors: [{detail: "Could not find media"}]}.to_json)
      error = assert_raises(MissingMediaData) { Uploader::Metadata.add_alt_text(7, "A cat", client: @client) }

      assert_equal ["The response that adds the metadata holds none: Could not find media", 1], [error.message, error.problems.size]
    end
  end
end
