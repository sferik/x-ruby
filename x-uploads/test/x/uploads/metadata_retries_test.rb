# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploads/metadata"

module X
  # Metadata is sent again after a failure no more than the max_retries of the client
  class MetadataRetriesTest < Minitest::Test
    cover Uploads::Metadata

    def setup
      @client = Client.new(max_retries: 0)
      stub_request(:post, %r{\Ahttps://api\.x\.com/2/media/(metadata|subtitles)\z}).to_return(status: 503)
    end

    def test_alt_text_is_not_sent_again_by_a_client_that_retries_nothing
      assert_raises(ServiceUnavailable) { Uploads::Metadata.add_alt_text(7, "A cat", client: @client) }
      assert_requested :post, "https://api.x.com/2/media/metadata", times: 1
    end

    def test_subtitles_are_not_sent_again_by_a_client_that_retries_nothing
      assert_raises(ServiceUnavailable) { Uploads::Metadata.add_subtitles(7, 8, "EN", client: @client) }
      assert_requested :post, "https://api.x.com/2/media/subtitles", times: 1
    end
  end
end
