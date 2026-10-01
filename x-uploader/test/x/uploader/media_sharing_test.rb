# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/media_upload"

module X
  # Media is shared, and given to users other than the one who uploads it, as the API takes each of an upload
  class MediaSharingTest < Minitest::Test
    cover Uploader::MediaUpload
    cover Uploader.const_get(:Chunks)
    cover Uploader.const_get(:Utils)
    cover Uploader.const_get(:Validator)

    BASE_URL = "https://api.x.com/2/media/upload"
    INIT_URL = "#{BASE_URL}/initialize".freeze
    VIDEO = "test/sample_files/sample.mp4"
    IMAGE = "test/sample_files/sample.png"
    JSON_HEADERS = {"content-type" => "application/json"}.freeze

    def setup
      @client = Client.new
    end

    def test_a_video_is_initialized_as_shared_with_its_additional_owners
      stub_chunks
      Uploader::MediaUpload.upload(VIDEO, client: @client, shared: true, additional_owners: [7_505_382, "783214"])

      assert_requested(:post, INIT_URL, body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: File.size(VIDEO),
                                               shared: true, additional_owners: %w[7505382 783214]}.to_json)
    end

    def test_a_video_uploaded_in_chunks_is_initialized_as_not_shared_when_told
      stub_chunks
      Uploader::MediaUpload.chunked_upload(VIDEO, client: @client, shared: false)

      assert_requested(:post, INIT_URL, body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: File.size(VIDEO), shared: false}.to_json)
    end

    def test_a_video_is_initialized_with_neither_unless_given
      stub_chunks
      Uploader::MediaUpload.chunked_upload(VIDEO, client: @client)

      assert_requested(:post, INIT_URL, body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: File.size(VIDEO)}.to_json)
    end

    def test_an_image_is_uploaded_in_a_single_request_with_its_additional_owners
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      Uploader::MediaUpload.upload(IMAGE, client: @client, additional_owners: [7_505_382, "783214"], shared: false)

      assert_requested(:post, BASE_URL) { |request| request.body.include?("name=\"additional_owners\"\r\n\r\n7505382,783214\r\n") }
      assert_requested(:post, BASE_URL) { |request| !request.body.include?("name=\"shared\"") }
    end

    def test_an_image_is_uploaded_in_a_single_request_without_additional_owners_unless_given
      stub_request(:post, BASE_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      Uploader::MediaUpload.upload(IMAGE, client: @client)

      assert_requested(:post, BASE_URL) { |request| !request.body.include?("additional_owners") }
    end

    def test_a_shared_image_is_uploaded_in_chunks_since_a_single_request_takes_no_shared
      stub_chunks
      Uploader::MediaUpload.upload(IMAGE, client: @client, media_category: "dm_image", shared: true)

      assert_requested(:post, INIT_URL, body: {media_type: "image/png", media_category: "dm_image", total_bytes: 68, shared: true}.to_json)
      assert_not_requested(:post, BASE_URL)
    end

    def test_shared_that_is_not_true_false_or_nil_is_refused_before_a_request
      %w[true false].push(1).each do |shared|
        error = assert_raises(ArgumentError) { Uploader::MediaUpload.upload(VIDEO, client: @client, shared:) }

        assert_equal "shared must be true, false, or nil, not #{shared.inspect}", error.message
      end
      assert_raises(ArgumentError) { Uploader::MediaUpload.chunked_upload(VIDEO, client: @client, shared: "true") }
    end

    def test_additional_owners_that_are_not_user_identifiers_are_refused_before_a_request
      [[], "7505382", [nil], [7_505_382, "abc"], ["abc"], [1.5], ["1" * 20], [-1], ["7505382\n"], [:"7505382"], 7_505_382].each do |additional_owners|
        error = assert_raises(ArgumentError) { Uploader::MediaUpload.upload(IMAGE, client: @client, additional_owners:) }

        assert_equal "additional_owners must be an Array of the identifiers of users, or nil for none, not #{additional_owners.inspect}", error.message
      end
      assert_raises(ArgumentError) { Uploader::MediaUpload.chunked_upload(VIDEO, client: @client, additional_owners: []) }
    end

    def test_additional_owners_of_as_many_digits_as_the_api_takes_are_taken
      stub_chunks
      Uploader::MediaUpload.chunked_upload(VIDEO, client: @client, additional_owners: Class.new(Array).new(["9" * 19, 0, Class.new(String).new("1")]))

      assert_requested(:post, INIT_URL, body: {media_type: "video/mp4", media_category: "tweet_video", total_bytes: File.size(VIDEO),
                                               additional_owners: ["9" * 19, "0", "1"]}.to_json)
    end

    private

    def stub_chunks
      stub_request(:post, INIT_URL).to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/append").to_return(status: 204)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(headers: JSON_HEADERS, body: {data: {id: TEST_MEDIA_ID}}.to_json)
    end
  end
end
