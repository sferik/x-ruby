# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # A certificate that does not verify will not verify the next time either, so a stream raises at once for one rather
  # than reconnect without end, while the other errors of TLS, as of the network, are reconnected after
  class StreamingClientCertificateTest < Minitest::Test
    cover StreamingClient
    cover Streams.const_get(:ReconnectHandler)

    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"
    HANDLER = Streams.const_get(:ReconnectHandler)
    UNVERIFIED = "SSL_connect returned=1 errno=0 peeraddr=104.244.42.66:443 state=error: certificate verify failed " \
      "(unable to get local issuer certificate)"

    def setup
      @sleeps, @reconnects = [], []
      @runs = 0
    end

    def test_a_stream_whose_certificate_does_not_verify_raises_at_once
      stub_request(:get, STREAM_URL).to_raise(OpenSSL::SSL::SSLError.new(UNVERIFIED))
      streaming_client = Client.new(bearer_token: TEST_BEARER_TOKEN).streaming(on_reconnect: ->(error, wait) { @reconnects << [error, wait] })
      error = assert_raises(NetworkError) { streaming_client.stream("tweets/sample/stream") { |_post| flunk "unexpected yield" } }

      assert_equal [OpenSSL::SSL::SSLError, UNVERIFIED, []], [error.cause.class, error.cause.message, @reconnects]
      assert_requested(:get, STREAM_URL, times: 1)
    end

    def test_a_certificate_that_does_not_verify_is_not_reconnected_after_with_reconnects_left
      assert_raises(NetworkError) { stream_with(HANDLER.new) { failing(OpenSSL::SSL::SSLError.new(UNVERIFIED)) } }
      assert_equal [1, []], [@runs, @sleeps]
    end

    def test_a_certificate_that_does_not_verify_is_told_by_an_error_of_any_class_of_tls
      assert_raises(NetworkError) { stream_with(HANDLER.new) { failing(OpenSSL::SSL::SSLErrorWaitReadable.new(UNVERIFIED)) } }
      assert_equal [1, []], [@runs, @sleeps]
    end

    def test_another_error_of_tls_is_reconnected_after
      assert_raises(NetworkError) { stream_with(HANDLER.new(max_reconnects: 2)) { failing(OpenSSL::SSL::SSLError.new("SSL_read: unexpected eof while reading")) } }
      assert_equal [3, [0.0, 0.25]], [@runs, @sleeps]
    end

    def test_an_error_that_says_the_same_but_is_not_one_of_tls_is_reconnected_after
      assert_raises(NetworkError) { stream_with(HANDLER.new(max_reconnects: 1)) { failing(IOError.new(UNVERIFIED)) } }
      assert_equal [2, [0.0]], [@runs, @sleeps]
    end

    def test_a_network_error_without_a_cause_is_reconnected_after
      assert_raises(NetworkError) { stream_with(HANDLER.new(max_reconnects: 1)) { (@runs += 1) && raise(NetworkError, UNVERIFIED) } }
      assert_equal [2, [0.0]], [@runs, @sleeps]
    end

    private

    # Raise a NetworkError whose cause is the error, as x-core raises one for an error of the socket
    def failing(cause)
      @runs += 1
      begin
        raise cause
      rescue cause.class
        raise NetworkError, "Network error: #{cause.message}"
      end
    end

    # Run a stream with the handler, noting each wait rather than waiting
    def stream_with(handler, &)
      handler.stub(:sleep, ->(seconds) { @sleeps << seconds }) { handler.handle(->(_object) {}, &) }
    end
  end
end
