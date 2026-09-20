require_relative "../../test_helper"

module X
  class ClientKeepAliveTest < Minitest::Test
    cover Client

    def test_a_client_keeps_connections_open_for_the_default_time
      assert_equal Connection::DEFAULT_KEEP_ALIVE_TIMEOUT, Client.new.keep_alive_timeout
    end

    def test_a_client_takes_a_keep_alive_timeout
      client = Client.new(keep_alive_timeout: 5)

      assert_equal 5, client.keep_alive_timeout
      assert_equal 5, client.instance_variable_get(:@connection).keep_alive_timeout
    end

    def test_setting_the_keep_alive_timeout_reaches_the_connection
      client = Client.new
      client.keep_alive_timeout = 5

      assert_equal 5, client.instance_variable_get(:@connection).keep_alive_timeout
    end

    def test_a_copy_keeps_the_keep_alive_timeout
      assert_equal 5, Client.new(keep_alive_timeout: 5).copy(read_timeout: 10).keep_alive_timeout
    end
  end
end
