# frozen_string_literal: true

require_relative "../../test_helper"
require "x/uploader/utils"

module X
  # A request of an upload is sent again as its client sends a request that is safe to send twice again
  class ChunksRetriesTest < Minitest::Test
    cover Uploader.const_get(:Utils)

    def utils = Uploader.const_get(:Utils)

    def test_a_request_is_sent_again_with_the_retries_of_the_client
      client = Object.new
      def client.with_retries = [:retried, yield]

      assert_equal [:retried, :sent], utils.sending_again(client) { :sent }
    end

    def test_a_request_of_a_client_without_retries_is_sent_as_the_client_sends_it
      assert_equal :sent, utils.sending_again(Object.new) { :sent }
    end
  end
end
