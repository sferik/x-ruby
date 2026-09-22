# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ConnectionStaleTest < Minitest::Test
    cover Connection
    cover Core::ConnectionRequest

    URL = "https://api.x.com/2/tweets"
    OTHER_URL = "https://example.com/2/tweets"

    def setup
      @connection = Connection.new
    end

    def test_a_request_on_a_connection_that_had_gone_stale_is_sent_again
      stub_request(:get, URL).to_return(status: 200).then.to_raise(EOFError).then.to_return(status: 200)
      @connection.perform(request: get_request(URL))

      assert_equal "200", @connection.perform(request: get_request(URL)).code
      assert_requested :get, URL, times: 3
    end

    def test_a_put_on_a_connection_that_had_gone_stale_is_sent_again
      assert_equal "200", sent_again(Net::HTTP::Put, :put).code
    end

    def test_a_delete_on_a_connection_that_had_gone_stale_is_sent_again
      assert_equal "200", sent_again(Net::HTTP::Delete, :delete).code
    end

    def test_a_post_on_a_connection_that_had_gone_stale_is_not_sent_again
      stub_request(:post, URL).to_return(status: 200).then.to_raise(EOFError)
      @connection.perform(request: Net::HTTP::Post.new(URI(URL)))

      assert_raises(NetworkError) { @connection.perform(request: Net::HTTP::Post.new(URI(URL))) }
      assert_requested :post, URL, times: 2
    end

    def test_a_request_on_a_connection_opened_for_it_is_not_sent_again
      stub_request(:get, URL).to_raise(EOFError)

      assert_raises(NetworkError) { @connection.perform(request: get_request(URL)) }
      assert_requested :get, URL, times: 1
    end

    def test_a_request_sent_again_is_not_sent_a_third_time
      stub_request(:get, URL).to_return(status: 200).then.to_raise(EOFError).then.to_raise(EOFError)
      @connection.perform(request: get_request(URL))

      assert_raises(NetworkError) { @connection.perform(request: get_request(URL)) }
      assert_requested :get, URL, times: 3
    end

    def test_a_request_sent_again_opens_a_connection_rather_than_take_the_one_that_failed
      stub_request(:get, URL).to_return(status: 200).then.to_raise(EOFError).then.to_return(status: 200)

      assert_equal 2, opened_while { 2.times { @connection.perform(request: get_request(URL)) } }.size
    end

    def test_a_request_that_timed_out_on_a_kept_connection_is_not_sent_again
      stub_request(:get, URL).to_return(status: 200).then.to_raise(Net::ReadTimeout).then.to_return(status: 200)
      @connection.perform(request: get_request(URL))

      assert_raises(NetworkError) { @connection.perform(request: get_request(URL)) }
      assert_requested :get, URL, times: 2
    end

    def test_a_request_reset_on_a_kept_connection_is_sent_again
      %w[ECONNRESET ECONNABORTED EPIPE].each do |name|
        WebMock.reset!
        stub_request(:get, URL).to_return(status: 200).then.to_raise(Errno.const_get(name)).then.to_return(status: 200)
        @connection.perform(request: get_request(URL))

        assert_equal "200", @connection.perform(request: get_request(URL)).code, name
      end
    end

    def test_a_request_sent_again_opens_a_connection_though_another_is_idle
      stub_request(:get, URL).to_raise(EOFError).then.to_return(status: 200)
      keep_idle(2)

      assert_equal 1, opened_while { @connection.perform(request: get_request(URL)) }.size
    end

    def test_a_request_whose_connection_fails_to_open_is_not_sent_again
      opened = 0
      failing = Net::HTTP.new("api.x.com", 443)
      def failing.start = raise(Errno::ECONNRESET)
      build = ->(*) { failing.tap { opened += 1 } }

      assert_raises(NetworkError) { @connection.stub(:build_http_client, build) { @connection.perform(request: get_request(URL)) } }
      assert_equal 1, opened
    end

    def test_the_connection_a_request_is_sent_again_on_is_kept_for_the_next_request
      stub_request(:get, URL).to_raise(EOFError).then.to_return(status: 200)
      keep_idle(1)

      assert_equal 1, opened_while { 2.times { @connection.perform(request: get_request(URL)) } }.size
    end

    def test_the_connections_of_each_host_are_kept_apart
      stub_request(:get, URL)
      stub_request(:get, OTHER_URL)
      opened = opened_while do
        [URL, OTHER_URL, URL].each { |url| @connection.perform(request: get_request(url)) }
      end

      assert_equal 2, opened.size
    end

    private

    # Send a request of the given class twice, the second on a connection the peer had closed
    def sent_again(http_method, verb)
      stub_request(verb, URL).to_return(status: 200).then.to_raise(EOFError).then.to_return(status: 200)
      @connection.perform(request: http_method.new(URI(URL)))
      @connection.perform(request: http_method.new(URI(URL)))
    end

    # Keep connections to the host of URL idle in the pool, as though earlier requests had used them
    def keep_idle(count)
      pool = @connection.instance_variable_get(:@pool)
      open = -> { @connection.send(:build_http_client, URI(URL)).tap { |http| http.use_ssl = true } }
      nest = ->(depth) { pool.with([true, "api.x.com", 443], open) { nest.call(depth - 1) if depth > 1 } }
      nest.call(count)
    end

    # The connections the block opened
    def opened_while(&)
      opened = []
      original = @connection.method(:build_http_client)
      @connection.stub(:build_http_client, ->(*args) { original.call(*args).tap { |http| opened << http } }, &)
      opened
    end
  end
end
