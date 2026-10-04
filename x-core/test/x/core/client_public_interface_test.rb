# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A client answers its settings, and nothing it reads them with, so the gems that extend it, and the code that
  # subclasses it, find no methods of Forwardable on the class
  class ClientPublicInterfaceTest < Minitest::Test
    cover_client

    def test_the_class_offers_no_way_to_define_delegators
      %i[def_delegator def_delegators delegate def_instance_delegator def_instance_delegators instance_delegate].each do |name|
        refute_respond_to Client, name
      end
    end

    def test_a_client_built_with_no_settings_takes_the_defaults
      client = Client.new

      assert_equal [Client::DEFAULT_OPEN_TIMEOUT, Client::DEFAULT_READ_TIMEOUT, Client::DEFAULT_WRITE_TIMEOUT, Client::DEFAULT_KEEP_ALIVE_TIMEOUT],
        [client.open_timeout, client.read_timeout, client.write_timeout, client.keep_alive_timeout]
      assert_equal [Client::DEFAULT_MAX_REDIRECTS, Client::DEFAULT_MAX_RATE_LIMIT_RETRIES, Client::DEFAULT_MAX_RATE_LIMIT_WAIT, Client::DEFAULT_MAX_RETRIES],
        [client.max_redirects, client.max_rate_limit_retries, client.max_rate_limit_wait, client.max_retries]
      assert_nil client.debug_output
    end

    def test_the_settings_are_the_ones_the_client_was_built_with
      debug_output = StringIO.new
      client = Client.new(open_timeout: 1, read_timeout: 2, write_timeout: 3, keep_alive_timeout: 4, debug_output:,
        max_redirects: 5, max_rate_limit_retries: 6, max_rate_limit_wait: 7, max_retries: 8)

      assert_equal [1, 2, 3, 4, 5, 6, 7, 8], [client.open_timeout, client.read_timeout, client.write_timeout, client.keep_alive_timeout,
        client.max_redirects, client.max_rate_limit_retries, client.max_rate_limit_wait, client.max_retries]
      assert_same debug_output, client.debug_output
    end
  end
end
