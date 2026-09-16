require "net/http"
require_relative "../../test_helper"

module X
  class ConnectionPoolTest < Minitest::Test
    cover ConnectionPool

    KEY = [true, "example.com", 443].freeze

    def setup
      stub_request(:get, "https://example.com/")
      @pool = ConnectionPool.new
      @opened = []
    end

    def open = -> { Net::HTTP.new("example.com", 443).tap { |http| http.use_ssl = true }.tap { |http| @opened << http } }

    def request(pool = @pool, key = KEY) = pool.with(key, open) { |http| http.request(Net::HTTP::Get.new(URI("https://example.com/"))) }

    def test_with_returns_what_the_block_returns_from_a_started_connection
      assert_equal [true, :ok], @pool.with(KEY, open) { |http| [http.started?, :ok] }
    end

    def test_reuses_the_connection_given_back_last
      nest(2)

      assert_same @opened.first, @pool.with(KEY, open) { |http| http }
    end

    def test_reuses_an_idle_connection
      2.times { request }

      assert_equal 1, @opened.size
      assert_predicate @opened.first, :started?
    end

    def test_keeps_connections_to_each_host_apart
      request
      request(@pool, [true, "example.com", 8443])

      assert_equal 2, @opened.size
    end

    def test_opens_a_connection_per_request_in_progress
      @pool.with(KEY, open) { @pool.with(KEY, open) { nil } }
      2.times { request }

      assert_equal 2, @opened.size
    end

    def test_keeps_no_more_than_the_maximum_idle
      nest(ConnectionPool::MAX_IDLE + 1)

      assert_equal ConnectionPool::MAX_IDLE, @opened.count(&:started?)
      nest(ConnectionPool::MAX_IDLE)

      assert_equal ConnectionPool::MAX_IDLE + 1, @opened.size
    end

    def test_closes_a_connection_whose_block_raises
      assert_raises(IOError) { @pool.with(KEY, open) { raise IOError } }
      request

      refute_predicate @opened.first, :started?
      assert_equal 2, @opened.size
    end

    def test_a_connection_that_fails_to_open_is_not_closed
      failing = -> { Net::HTTP.new("example.com", 443).tap { |http| http.define_singleton_method(:start) { raise SocketError } } }

      assert_raises(SocketError) { @pool.with(KEY, failing) { flunk "yielded" } }
    end

    def test_clear_closes_idle_connections_and_opens_new_ones
      request
      @pool.clear
      request

      assert_equal [false, true], @opened.map(&:started?)
    end

    def test_clear_closes_a_connection_in_use_once_it_is_done
      @pool.with(KEY, open) { @pool.clear }
      request

      assert_equal [false, true], @opened.map(&:started?)
    end

    def test_clear_ignores_a_connection_that_is_already_closed
      request
      @opened.first.define_singleton_method(:finish) { raise IOError, "closed stream" }
      @pool.clear
      request

      assert_equal 2, @opened.size
    end

    def test_a_forked_process_opens_connections_of_its_own
      request
      Process.stub(:pid, Process.pid + 1) { 2.times { request } }

      assert_equal 2, @opened.size
      assert_predicate @opened.first, :started?
    end

    private

    def nest(depth)
      return if depth.zero?

      @pool.with(KEY, open) { nest(depth - 1) }
    end
  end

  class ConnectionPoolLockTest < Minitest::Test
    cover ConnectionPool

    KEY = ConnectionPoolTest::KEY

    def setup
      stub_request(:get, "https://example.com/")
      @pool = ConnectionPool.new
      @opened = []
    end

    def open = -> { Net::HTTP.new("example.com", 443).tap { |http| http.use_ssl = true }.tap { |http| @opened << http } }

    def test_taking_a_connection_waits_for_the_lock
      reached = Queue.new
      assert_waits_for_lock { Thread.new { @pool.with(KEY, open) { reached << true } } }

      assert_equal 1, reached.size
    end

    def test_clearing_waits_for_the_lock
      assert_waits_for_lock { Thread.new { @pool.clear } }
    end

    def test_giving_a_connection_back_waits_for_the_lock
      inside, go, done = Array.new(3) { Queue.new }
      thread = Thread.new { @pool.with(KEY, open) { (inside << true) && (done << go.pop) } }
      inside.pop
      assert_waits_for_lock(opened: 1) do
        go << true
        done.pop
        thread
      end
    end

    private

    # Hold the pool's lock while a block starts a thread, and check that the thread waits for it
    def assert_waits_for_lock(opened: 0)
      thread = nil
      @pool.instance_variable_get(:@lock).synchronize do
        thread = yield
        sleep 0.05

        assert_predicate thread, :alive?
        assert_equal opened, @opened.size
      end
      thread.join
    end
  end

  class ConnectionKeepAliveTest < Minitest::Test
    cover Connection

    def setup
      stub_request(:get, "https://example.com/")
      @connection = Connection.new
    end

    def perform = @connection.perform(request: Net::HTTP::Get.new(URI("https://example.com/")))

    def opened(&)
      clients = []
      original = @connection.method(:build_http_client)
      @connection.stub(:build_http_client, ->(*args) { original.call(*args).tap { |client| clients << client } }, &)
      clients
    end

    def test_requests_to_a_host_share_a_connection
      clients = opened { 2.times { perform } }

      assert_equal 1, clients.size
      assert_predicate clients.first, :started?
      assert_predicate clients.first, :use_ssl?
    end

    def test_a_reused_connection_takes_the_current_timeouts
      clients = opened do
        perform
        @connection.read_timeout = 5
        @connection.open_timeout = 6
        @connection.write_timeout = 7
        perform
      end

      assert_equal [5, 6, 7], [clients.first.read_timeout, clients.first.open_timeout, clients.first.write_timeout]
    end

    def test_requests_to_another_scheme_host_or_port_open_their_own_connections
      urls = %w[https://example.com/ http://example.com:443/ https://example.org/ https://example.com:8443/]
      urls.each { |url| stub_request(:get, url) }
      clients = opened { urls.each { |url| @connection.perform(request: Net::HTTP::Get.new(URI(url))) } }

      assert_equal 4, clients.size
    end

    def test_a_request_to_http_does_not_use_ssl
      stub_request(:get, "http://example.com/")
      clients = opened { @connection.perform(request: Net::HTTP::Get.new(URI("http://example.com/"))) }

      refute_predicate clients.first, :use_ssl?
    end

    def test_changing_the_debug_output_opens_new_connections_with_it
      clients = opened do
        perform
        @connection.debug_output = StringIO.new
        perform
      end

      assert_equal [false, true], clients.map(&:started?)
      assert_same @connection.debug_output, clients.last.instance_variable_get(:@debug_output)
    end

    def test_changing_the_proxy_opens_new_connections
      clients = opened do
        perform
        @connection.proxy_url = "http://proxy.example.com:8080"
      end

      refute_predicate clients.first, :started?
    end

    def test_close_closes_the_connections_kept_open
      clients = opened do
        perform
        @connection.close
      end

      refute_predicate clients.first, :started?
    end

    def test_a_network_error_closes_the_connection
      stub_request(:get, "https://example.com/").to_raise(Errno::ECONNRESET).then.to_return(status: 200)
      clients = opened do
        assert_raises(NetworkError) { perform }
        perform
      end

      assert_equal [false, true], clients.map(&:started?)
    end
  end
end
