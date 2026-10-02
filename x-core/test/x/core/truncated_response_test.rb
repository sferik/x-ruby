# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A response whose connection drops before its body is read whole, read from a server on the loopback interface,
  # since webmock passes a response to the block of a request only once it has read the body
  class TruncatedResponseTest < Minitest::Test
    include LocalServer

    cover_client
    cover Core.const_get(:Connection)
    cover Core.const_get(:ConnectionRequest)

    OK = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 11\r\n\r\n{\"data\":{}}"
    CHUNKED = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nTransfer-Encoding: chunked\r\n\r\n8\r\n{\"data\":\r\n"
    SHORT = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 11\r\n\r\n{\"data\":"

    def url(port) = "http://127.0.0.1:#{port}/2/users/me"

    def client(port) = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://127.0.0.1:#{port}/2/", max_retries: 1)

    def test_a_get_on_a_kept_connection_whose_body_is_cut_off_is_not_sent_again
      with_local_connections([OK, CHUNKED], [OK]) do |port, requests|
        connection = Core.const_get(:Connection).new
        connection.perform(request: get_request(url(port)))
        error = assert_raises(NetworkError) { connection.perform(request: get_request(url(port))) }

        assert_equal [EOFError, 2], [error.cause.class, requests.size]
      end
    end

    def test_a_body_shorter_than_its_content_length_raises_a_network_error
      with_local_connections([SHORT]) do |port|
        error = assert_raises(NetworkError) { Core.const_get(:Connection).new.perform(request: get_request(url(port))) }

        assert_kind_of EOFError, error.cause
      end
    end

    def test_a_lookup_whose_body_is_cut_off_is_not_sent_again
      with_local_connections([SHORT], [OK]) do |port, requests|
        assert_raises(NetworkError) { client(port).get("users/me") }
        assert_equal 1, requests.size
      end
    end

    def test_a_lookup_whose_body_is_cut_off_is_sent_again_by_with_retries
      with_local_connections([SHORT], [OK]) do |port, requests|
        client = client(port)
        handler = internals(client).instance_variable_get(:@retry_handler)

        assert_equal({"data" => {}}, handler.stub(:sleep, nil) { client.with_retries { client.get("users/me") } })
        assert_equal 2, requests.size
      end
    end
  end
end
