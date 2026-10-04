# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A proxy of the environment that cannot be parsed is refused by each request that reads it, with an ArgumentError
  # that names the variables it is read from and holds nothing of its value, as the proxy URL a client is given is
  # refused; the host is an address, which is not resolved, and not the loopback one, which no proxy is read for
  class ConnectionProxyEnvironmentErrorTest < Minitest::Test
    include ProxyEnvironment

    cover_client
    cover Core.const_get(:Connection)
    cover Core.const_get(:ConnectionProxy)

    BASE_URL = "http://192.0.2.1/2/"
    # A proxy URL whose password holds a #, which ends the authority of a URL
    UNPARSEABLE = "http://user:hun#ter2@10.0.0.1:3128"
    MESSAGE = "Invalid proxy URL in the environment, in http_proxy, HTTP_PROXY, or CGI_HTTP_PROXY"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: BASE_URL)
    end

    def test_each_request_refuses_a_proxy_of_the_environment_that_cannot_be_parsed
      %i[get post put delete].each do |http_method|
        error = with_proxy_env(http_proxy: UNPARSEABLE) { assert_raises(ArgumentError) { @client.public_send(http_method, "users/me") } }

        assert_equal [ArgumentError, MESSAGE], [error.class, error.message]
      end
      assert_not_requested :any, /192\.0\.2\.1/
    end

    def test_the_error_holds_nothing_of_the_password
      error = with_proxy_env(http_proxy: UNPARSEABLE) { assert_raises(ArgumentError) { @client.get("users/me") } }

      assert_nil error.cause
      [error.full_message, error.detailed_message, error.inspect].each { |text| refute_includes text, "ter2" }
    end

    def test_a_stream_refuses_a_proxy_of_the_environment_that_cannot_be_parsed
      error = with_proxy_env(http_proxy: UNPARSEABLE) { assert_raises(ArgumentError) { @client.get_stream("stream", &:read_body) } }

      assert_equal [ArgumentError, MESSAGE, nil], [error.class, error.message, error.cause]
    end

    def test_the_request_of_an_app_only_token_refuses_it
      client = Client.new(api_key: TEST_API_KEY, api_key_secret: TEST_API_KEY_SECRET, base_url: BASE_URL)
      error = with_proxy_env(http_proxy: UNPARSEABLE) { assert_raises(ArgumentError) { client.get("users/1") } }

      assert_equal [ArgumentError, MESSAGE, nil], [error.class, error.message, error.cause]
    end

    def test_the_refresh_of_an_oauth2_token_refuses_it
      client = Client.new(**test_oauth2_credentials, expires_at: Time.now - 60, base_url: BASE_URL)
      error = with_proxy_env(http_proxy: UNPARSEABLE) { assert_raises(ArgumentError) { client.get("users/me") } }

      assert_equal [ArgumentError, MESSAGE, nil], [error.class, error.message, error.cause]
    end

    def test_the_request_is_not_sent_again_for_it
      attempts = 0
      request = -> { @client.with_retries { @client.get("users/me", headers: {"Attempt" => (attempts += 1).to_s}) } }

      with_proxy_env(http_proxy: UNPARSEABLE) { assert_raises(ArgumentError, &request) }

      assert_equal 1, attempts
    end

    def test_an_address_without_a_scheme_is_refused
      error = with_proxy_env(http_proxy: "10.0.0.1:3128") { assert_raises(ArgumentError) { @client.get("users/me") } }

      assert_equal MESSAGE, error.message
    end

    def test_the_error_a_connection_raises_inside_a_request_has_no_cause
      connection = Core.const_get(:Connection).new
      error = with_proxy_env(http_proxy: UNPARSEABLE) do
        assert_raises(Core.const_get(:ConnectionProxy).const_get(:InvalidEnvironmentProxy)) { connection.send(:proxy_for, URI(BASE_URL)) }
      end

      assert_nil error.cause
    end

    def test_a_client_given_a_proxy_url_does_not_read_the_proxy_of_the_environment
      stub_request(:get, "#{BASE_URL}users/me").to_return(body: "{}", headers: {"Content-Type" => "application/json"})
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: BASE_URL, proxy_url: "http://proxy.example.com:3128")

      assert_equal({}, with_proxy_env(http_proxy: UNPARSEABLE) { client.get("users/me") })
    end

    def test_a_host_no_proxy_names_is_reached_without_reading_the_proxy
      stub_request(:get, "#{BASE_URL}users/me").to_return(body: "{}", headers: {"Content-Type" => "application/json"})

      assert_equal({}, with_proxy_env(http_proxy: UNPARSEABLE, no_proxy: "192.0.2.1") { @client.get("users/me") })
    end
  end
end
