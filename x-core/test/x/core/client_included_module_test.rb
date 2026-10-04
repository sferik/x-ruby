# frozen_string_literal: true

require "json"
require "yaml"
require_relative "../../test_helper"

module X
  # A module included into a client, as x-resources and x-uploads are, may name its methods as it likes, and so may
  # name one raise, format, or block_given?, which take the place of none of the methods of the client
  class ClientIncludedModuleTest < Minitest::Test
    cover Client
    cover Core.const_get(:CredentialHolder)

    # A module whose methods have the names of Kernel methods a client could otherwise call on itself
    KERNEL_NAMES = Module.new do
      def raise(*) = :raised_by_the_module
      def format(*) = :formatted_by_the_module
      def block_given? = true
    end

    def setup
      @client = Class.new(Client) { include KERNEL_NAMES }.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_a_client_refuses_to_be_written_whatever_an_included_module_names_its_methods
      [-> { Marshal.dump(@client) }, -> { @client.encode_with(nil) }, -> { @client.as_json }, -> { @client.to_json }].each do |write|
        assert_match(/holds credentials/, assert_raises(TypeError, &write).message)
      end
    end

    def test_a_stream_without_a_block_is_refused_whatever_an_included_module_names_its_methods
      error = assert_raises(ArgumentError) { @client.get_stream("tweets/sample/stream") }

      assert_equal "get_stream takes a block, which reads the body of the response", error.message
      assert_not_requested :get, %r{tweets/sample/stream}
    end
  end
end
