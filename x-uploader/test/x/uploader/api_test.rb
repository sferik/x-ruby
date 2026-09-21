# frozen_string_literal: true

require "stringio"
require_relative "../../test_helper"

module X
  class UploaderAPITest < Minitest::Test
    cover Uploader::API

    def setup
      @client = Class.new(Client) { include Uploader::API }.new(**test_oauth_credentials)
      @called = ->(*arguments, **options) { [arguments, options] }
    end

    def test_upload_media_uploads_a_file_with_the_client_and_its_options
      Uploader::MediaUpload.stub(:upload, @called) do
        assert_equal [["cat.jpg"], {client: @client, alt_text: "A cat"}], @client.upload_media("cat.jpg", alt_text: "A cat")
      end
    end

    def test_await_media_processing_returns_the_status_of_media_that_failed_as_await_processing_does
      Uploader::MediaUpload.stub(:await_processing, @called) do
        assert_equal [[7], {client: @client, processing_timeout: 60}], @client.await_media_processing(7, processing_timeout: 60)
      end
    end

    def test_await_media_processing_bang_raises_for_media_that_failed_as_await_processing_bang_does
      Uploader::MediaUpload.stub(:await_processing!, @called) do
        assert_equal [[7], {client: @client, processing_timeout: 60}], @client.await_media_processing!(7, processing_timeout: 60)
      end
    end

    def test_add_alt_text_describes_media_with_the_client
      Uploader::Metadata.stub(:add_alt_text, @called) do
        assert_equal [[{"id" => "7"}, "A cat"], {client: @client}], @client.add_alt_text({"id" => "7"}, "A cat")
      end
    end

    def test_add_subtitles_attaches_subtitles_with_the_client_and_its_options
      Uploader::Metadata.stub(:add_subtitles, @called) do
        assert_equal [[7, 8, "EN"], {client: @client, display_name: "English"}], @client.add_subtitles(7, 8, "EN", display_name: "English")
      end
    end

    def test_update_profile_image_updates_it_with_the_client
      Uploader::Account.stub(:update_profile_image, @called) do
        assert_equal [["avatar.png"], {client: @client}], @client.update_profile_image("avatar.png")
      end
    end

    def test_update_profile_banner_updates_it_with_the_client_and_its_options
      Uploader::Account.stub(:update_profile_banner, @called) do
        assert_equal [["banner.png"], {client: @client, width: 1500}], @client.update_profile_banner("banner.png", width: 1500)
      end
    end

    def test_a_client_gains_nothing_until_it_includes_the_methods
      refute_includes Client.ancestors, Uploader::API
      assert_equal %i[add_alt_text add_subtitles await_media_processing await_media_processing! update_profile_banner update_profile_image
        upload_media], Uploader::API.public_instance_methods.sort
    end

    def test_await_media_processing_reports_a_failure_and_the_bang_raises_it
      failed = {data: {id: "7", processing_info: {state: "failed", error: {message: "Unsupported video format"}}}}
      stub_request(:get, "https://api.x.com/2/media/upload?command=STATUS&media_id=7")
        .to_return(headers: {"content-type" => "application/json"}, body: failed.to_json)

      assert_predicate @client.await_media_processing(7), :failed?
      assert_raises(Uploader::MediaProcessingFailed) { @client.await_media_processing!(7) }
    end

    def test_an_upload_reaches_the_api_through_the_client
      stub_request(:post, "https://api.x.com/2/media/upload").to_return(headers: {"content-type" => "application/json"}, body: {data: {id: "7"}}.to_json)

      assert_equal(Uploader::UploadedMedia.new({"id" => "7"}), @client.upload_media(StringIO.new("GIF89a"), media_category: "tweet_image"))
    end
  end
end
