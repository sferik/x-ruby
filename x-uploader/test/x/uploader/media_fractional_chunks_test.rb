# frozen_string_literal: true

require "tmpdir"
require_relative "../../test_helper"
require "x/uploader/media"

module X
  class MediaFractionalChunksTest < Minitest::Test
    cover Uploader::Media

    BASE_URL = "https://api.x.com/2/media/upload"
    APPEND_URL = "#{BASE_URL}/#{TEST_MEDIA_ID}/append".freeze
    CONTENT = Array.new(4000) { |index| (index % 251).chr }.join.b.freeze

    def setup
      @client = Client.new
      @chunks = Queue.new
      json = {headers: {"content-type" => "application/json"}, body: {data: {id: TEST_MEDIA_ID}}.to_json}
      stub_request(:post, "#{BASE_URL}/initialize").to_return(json)
      stub_request(:post, "#{BASE_URL}/#{TEST_MEDIA_ID}/finalize").to_return(json)
      stub_request(:post, APPEND_URL).to_return do |request|
        body = request.body.b
        @chunks << [body[/name="segment_index"\r\n\r\n(\d+)/, 1].to_i, body[/octet-stream\r\n\r\n(.*)\r\n--\h+--\r\n\z/m, 1]]
        {status: 204}
      end
    end

    def test_a_fractional_chunk_size_is_rounded_up_to_a_whole_byte_and_sends_every_byte
      Dir.mktmpdir do |dir|
        path = File.join(dir, "video.mp4")
        File.binwrite(path, CONTENT)
        Uploader::Media.chunked_upload(path, client: @client, media_category: "tweet_video", chunk_size_mb: 1000.5 / Uploader::Media::BYTES_PER_MB)
      end
      chunks = Array.new(@chunks.size) { @chunks.pop }.sort.map(&:last)

      assert_equal [1001, 1001, 1001, 997], chunks.map(&:bytesize)
      assert_equal CONTENT, chunks.join
    end
  end
end
