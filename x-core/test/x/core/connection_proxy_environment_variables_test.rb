# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The error of a proxy of the environment that cannot be parsed names each variable that is read for the scheme of
  # the request, in either case, so it is true whichever of them was set: https_proxy or HTTPS_PROXY for HTTPS, and
  # http_proxy, HTTP_PROXY, or, in a CGI process, CGI_HTTP_PROXY for HTTP
  class ConnectionProxyEnvironmentVariablesTest < Minitest::Test
    include ProxyEnvironment

    cover_client
    cover Core.const_get(:Connection)
    cover Core.const_get(:ConnectionProxy)

    # A proxy URL whose password holds a #, which ends the authority of a URL
    UNPARSEABLE = "http://user:hun#ter2@10.0.0.1:3128"
    MESSAGE = "Invalid proxy URL in the environment, in http_proxy, HTTP_PROXY, or CGI_HTTP_PROXY"
    HTTPS_MESSAGE = "Invalid proxy URL in the environment, in https_proxy or HTTPS_PROXY"

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "http://192.0.2.1/2/")
    end

    def test_the_variables_are_named_by_the_scheme_of_the_request
      error = with_proxy_env(https_proxy: UNPARSEABLE) { assert_raises(ArgumentError) { https_client.get("users/me") } }

      assert_equal HTTPS_MESSAGE, error.message
    end

    def test_the_message_is_true_of_an_uppercase_https_proxy
      error = with_proxy_env { with_env("HTTPS_PROXY" => UNPARSEABLE) { assert_raises(ArgumentError) { https_client.get("users/me") } } }

      assert_equal [HTTPS_MESSAGE, nil], [error.message, error.cause]
      refute_includes error.full_message, "ter2"
    end

    def test_the_message_is_true_of_an_uppercase_http_proxy
      error = with_proxy_env do
        with_env("HTTP_PROXY" => UNPARSEABLE) { silencing_warnings { assert_raises(ArgumentError) { @client.get("users/me") } } }
      end

      assert_equal [MESSAGE, nil], [error.message, error.cause]
      refute_includes error.full_message, "ter2"
    end

    def test_the_message_is_true_of_the_http_proxy_of_a_cgi_process
      error = with_proxy_env do
        with_env("REQUEST_METHOD" => "GET", "CGI_HTTP_PROXY" => UNPARSEABLE) { assert_raises(ArgumentError) { @client.get("users/me") } }
      end

      assert_equal [MESSAGE, nil], [error.message, error.cause]
      refute_includes error.full_message, "ter2"
    end

    def test_a_stream_names_the_variables_of_an_https_request
      error = with_proxy_env(https_proxy: UNPARSEABLE) { assert_raises(ArgumentError) { https_client.get_stream("stream", &:read_body) } }

      assert_equal [HTTPS_MESSAGE, nil], [error.message, error.cause]
    end

    private

    # A client of a host reached over HTTPS, which the https_proxy of the environment is read for
    def https_client = Client.new(bearer_token: TEST_BEARER_TOKEN, base_url: "https://192.0.2.1/2/")

    # Run a block with variables of the environment that with_proxy_env does not set, and restore them after it
    def with_env(values)
      original = values.keys.to_h { |name| [name, ENV.fetch(name, nil)] }
      values.each { |name, value| ENV[name] = value }
      yield
    ensure
      original.each { |name, value| ENV[name] = value }
    end

    # Run a block without the warning URI::Generic#find_proxy writes for an HTTP_PROXY it reads
    def silencing_warnings
      verbose, $VERBOSE = $VERBOSE, nil
      yield
    ensure
      $VERBOSE = verbose
    end
  end
end
