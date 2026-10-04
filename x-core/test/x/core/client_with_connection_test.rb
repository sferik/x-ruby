# frozen_string_literal: true

require "socket"
require "stringio"
require_relative "../../test_helper"

module X
  # A copy that opens its connections as the client does shares the connections the client keeps open
  class ClientWithConnectionTest < Minitest::Test
    cover_client
    cover Core.const_get(:Connection)

    def setup
      @client = Client.new(bearer_token: "TEST_BEARER_TOKEN")
    end

    def test_a_copy_that_sends_other_headers_shares_the_connections
      with_keep_alive_server do |port, accepted|
        client = Client.new(bearer_token: "TEST_BEARER_TOKEN", base_url: "http://127.0.0.1:#{port}/2/")
        3.times { |trace| client.with(headers: {"X-Trace" => trace.to_s}).get("users/me") }
        client.get("users/me")

        assert_equal 1, accepted.size
      ensure
        client&.close
      end
    end

    def test_a_copy_that_sends_elsewhere_shares_the_connections
      [{headers: {"X-Trace" => "abc"}}, {base_url: "https://api.x.com/1.1/"}, {bearer_token: "OTHER"}, {max_retries: 0}].each do |options|
        assert_same pool_of(@client), pool_of(@client.with(**options)), options.inspect
      end
    end

    def test_a_copy_that_opens_its_connections_otherwise_keeps_its_own
      [{open_timeout: 1}, {read_timeout: 1}, {write_timeout: 1}, {keep_alive_timeout: 1}, {debug_output: StringIO.new},
        {proxy_url: "http://proxy.example.com:8080"}].each do |options|
        refute_same pool_of(@client), pool_of(@client.with(**options)), options.inspect
      end
    end

    def test_a_copy_given_the_settings_the_client_holds_shares_the_connections
      output = StringIO.new
      client = Client.new(bearer_token: "TEST_BEARER_TOKEN", read_timeout: 5, debug_output: output, proxy_url: "http://proxy.example.com:8080")

      assert_same pool_of(client), pool_of(client.with(read_timeout: 5.0, debug_output: output, proxy_url: "http://proxy.example.com:8080".dup))
    end

    def test_a_copy_given_an_equal_debug_output_that_is_another_object_keeps_its_own
      client = Client.new(bearer_token: "TEST_BEARER_TOKEN", debug_output: [])

      refute_same pool_of(client), pool_of(client.with(debug_output: []))
    end

    def test_a_copy_given_an_equal_debug_output_writes_its_requests_to_its_own
      mine, its = [], []
      with_keep_alive_server do |port, _accepted|
        client = Client.new(bearer_token: "TEST_BEARER_TOKEN", base_url: "http://127.0.0.1:#{port}/2/", debug_output: mine)
        copy = client.with(debug_output: its)
        [client.get("mine"), copy.get("its")]
      ensure
        [client, copy].each { |opened| opened&.close }
      end

      assert_equal [[true, false], [false, true]], [mine, its].map { |output| %w[/2/mine /2/its].map { |path| output.join.include?("GET #{path} ") } }
    end

    private

    def pool_of(client) = internals(client).instance_variable_get(:@connection).__send__(:pool)

    # Serve every request on a port of the loopback, keeping each connection open, and yield the port and the
    # connections accepted
    def with_keep_alive_server
      server = TCPServer.new("127.0.0.1", 0)
      accepted = []
      thread = Thread.new { loop { accepted << serve(server.accept) } }
      WebMock.allow_net_connect!
      yield server.addr[1], accepted
    ensure
      WebMock.disable_net_connect!
      thread&.kill
      accepted&.each(&:kill)
      server&.close
    end

    # Answer each request a connection sends with an empty JSON object, until it closes
    def serve(socket)
      Thread.new do
        while socket.gets
          nil until socket.gets.eql?("\r\n")
          socket.write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 2\r\n\r\n{}")
        end
      rescue IOError, SystemCallError
        nil
      ensure
        socket.close
      end
    end
  end
end
