# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A proxy of the environment is held to what a proxy URL given is, an HTTP or HTTPS URL that names a host, so one
  # without a scheme, which Net::HTTP would take for no proxy at all, is refused by the request that reads it, rather
  # than sent around the proxy; the host is an address, which is not resolved, and not the loopback one
  class ConnectionProxyEnvironmentURLTest < Minitest::Test
    include ProxyEnvironment

    cover_client
    cover Core.const_get(:Connection)
    cover Core.const_get(:ConnectionProxy)

    BASE_URL = "http://192.0.2.1/2/"
    URI_ME = URI("#{BASE_URL}users/me")
    MESSAGE = "Invalid proxy URL in the environment, in http_proxy, HTTP_PROXY, or CGI_HTTP_PROXY"
    HTTPS_MESSAGE = "Invalid proxy URL in the environment, in https_proxy or HTTPS_PROXY"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: BASE_URL)
    end

    def test_a_host_and_port_without_a_scheme_is_refused
      assert_equal [ArgumentError, MESSAGE, nil], refused("proxy.example.com:8080")
      assert_not_requested :any, /192\.0\.2\.1/
    end

    def test_a_host_without_a_scheme_is_refused
      assert_equal [ArgumentError, MESSAGE, nil], refused("proxy.example.com")
    end

    def test_a_url_of_another_scheme_is_refused
      %w[socks5://proxy.example.com:1080 socks://proxy.example.com ftp://proxy.example.com:21 ws://proxy.example.com].each do |proxy|
        assert_equal [ArgumentError, MESSAGE, nil], refused(proxy), proxy
      end
    end

    def test_a_url_that_names_no_host_is_refused
      %w[http:// http:///path http://:8080 https:// http:proxy.example.com:8080].each do |proxy|
        assert_equal [ArgumentError, MESSAGE, nil], refused(proxy), proxy
      end
    end

    def test_a_value_that_holds_whitespace_is_refused
      [" ", " http://proxy.example.com:3128", "http://proxy.example.com:3128 ", "proxy.example.com 8080"].each do |proxy|
        assert_equal [ArgumentError, MESSAGE, nil], refused(proxy), proxy.inspect
      end
    end

    def test_the_error_holds_nothing_of_the_value
      error = with_proxy_env(http_proxy: "user:hunter2@proxy.example.com:8080") { assert_raises(ArgumentError) { @client.get("users/me") } }

      [error.full_message, error.detailed_message, error.inspect].each { |text| refute_match(/hunter2|proxy\.example/, text) }
    end

    def test_the_variables_are_named_by_the_scheme_of_the_request
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "https://192.0.2.1/2/")
      error = with_proxy_env(https_proxy: "proxy.example.com:8080") { assert_raises(ArgumentError) { client.get("users/me") } }

      assert_equal [ArgumentError, HTTPS_MESSAGE, nil], [error.class, error.message, error.cause]
    end

    def test_a_stream_refuses_a_proxy_without_a_scheme
      error = with_proxy_env(http_proxy: "proxy.example.com:8080") { assert_raises(ArgumentError) { @client.get_stream("stream", &:read_body) } }

      assert_equal [ArgumentError, MESSAGE, nil], [error.class, error.message, error.cause]
    end

    def test_the_request_is_not_sent_again_for_it
      attempts = 0
      request = -> { @client.with_retries { @client.get("users/me", headers: {"Attempt" => (attempts += 1).to_s}) } }

      with_proxy_env(http_proxy: "proxy.example.com:8080") { assert_raises(ArgumentError, &request) }

      assert_equal 1, attempts
    end

    def test_what_a_proxy_url_given_refuses_is_refused_of_the_environment
      %w[proxy.example.com:8080 proxy.example.com socks5://proxy.example.com:1080 http:// http:proxy:8080 //proxy.example.com:8080].each do |proxy|
        assert_raises(ArgumentError, proxy) { Client.new(proxy_url: proxy) }
        assert_equal MESSAGE, refused(proxy)[1], proxy
      end
    end

    def test_a_url_with_a_user_and_password_is_the_proxy
      proxy = with_proxy_env(http_proxy: "http://user:p%40ss@proxy.example.com:3128") { http_client }

      assert_equal ["proxy.example.com", 3128, "user", "p@ss", false], [proxy.proxy_address, proxy.proxy_port, proxy.proxy_user, proxy.proxy_pass, proxy.instance_variable_get(:@proxy_use_ssl)]
    end

    def test_what_a_proxy_url_given_allows_is_the_proxy_of_the_environment
      {"HTTP://proxy.example.com" => ["proxy.example.com", 80, false], "http://proxy.example.com:3128/path?query" => ["proxy.example.com", 3128, false],
       "https://proxy.example.com" => ["proxy.example.com", 443, true], "http://[::1]:3128" => ["::1", 3128, false]}.each do |proxy, expected|
        given = Core.const_get(:Connection).new(proxy_url: proxy).send(:build_http_client, URI_ME)
        named = with_proxy_env(http_proxy: proxy) { http_client }

        assert_equal [expected, expected], [given, named].map { |http| [http.proxy_address, http.proxy_port, http.instance_variable_get(:@proxy_use_ssl)] }, proxy
      end
    end

    def test_an_empty_variable_names_no_proxy
      stub_request(:get, URI_ME).to_return(body: "{}", headers: {"Content-Type" => "application/json"})

      assert_equal [false, {}], with_proxy_env(http_proxy: "") { [http_client.proxy?, @client.get("users/me")] }
    end

    def test_a_host_no_proxy_names_is_reached_without_checking_the_proxy
      stub_request(:get, URI_ME).to_return(body: "{}", headers: {"Content-Type" => "application/json"})

      assert_equal({}, with_proxy_env(http_proxy: "proxy.example.com:8080", no_proxy: "192.0.2.1") { @client.get("users/me") })
    end

    def test_a_client_given_a_proxy_url_does_not_check_the_proxy_of_the_environment
      stub_request(:get, URI_ME).to_return(body: "{}", headers: {"Content-Type" => "application/json"})
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: BASE_URL, proxy_url: "http://proxy.example.com:3128")

      assert_equal({}, with_proxy_env(http_proxy: "proxy.example.com:8080") { client.get("users/me") })
    end

    private

    # The class, message, and cause of the error a request raises for the http_proxy of the environment
    def refused(proxy)
      error = with_proxy_env(http_proxy: proxy) { assert_raises(ArgumentError) { @client.get("users/me") } }

      [error.class, error.message, error.cause]
    end

    # The HTTP client a connection given no proxy builds for a request
    def http_client = Core.const_get(:Connection).new.send(:build_http_client, URI_ME)
  end
end
