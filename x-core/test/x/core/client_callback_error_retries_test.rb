# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An error a callback of a request raises is raised as it was by Client#with_retries too, which runs outside the
  # request, rather than taken for a failure of the API, which would send the request again though the API answered it
  class ClientCallbackErrorRetriesTest < Minitest::Test
    cover "X::Client#with_retries"
    cover "X::Core::ClientSettings#with_retries"
    cover Core.const_get(:CallbackError)
    cover Core.const_get(:RetryHandler)

    URL = "https://api.x.com/2/tweets"
    STREAM_URL = "https://api.x.com/2/tweets/sample/stream"
    SUCCESS = {status: 200, body: '{"data":{"id":"1"}}', headers: {"Content-Type" => "application/json"}}.freeze

    def setup
      stub_request(:post, URL).to_return(SUCCESS)
      stub_request(:get, STREAM_URL).to_return(status: 200, body: "")
    end

    def test_a_post_is_not_sent_again_for_a_server_error_the_hook_raises
      failure = ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
      client = Client.new(on_response: ->(_) { raise failure })

      assert_same failure, without_retries(client) { assert_raises(ServiceUnavailable) { client.with_retries { client.post("tweets", "{}") } } }
      assert_requested :post, URL, times: 1
    end

    def test_a_post_is_not_sent_again_for_a_network_error_from_response_raises
      failure = NetworkError.new("the lookup it made failed")
      client = Client.new
      object_class = Class.new { define_singleton_method(:from_response) { |_, client:| raise failure } }

      assert_same failure, without_retries(client) { assert_raises(NetworkError) { client.with_retries { client.post("tweets", "{}", object_class:) } } }
      assert_requested :post, URL, times: 1
    end

    def test_a_stream_is_not_opened_again_for_a_server_error_its_block_raises
      failure = InternalServerError.new(http_response: Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error"))
      client = Client.new

      assert_same failure, without_retries(client) { assert_raises(InternalServerError) { client.with_retries { client.get_stream("tweets/sample/stream") { |_| raise failure } } } }
      assert_requested :get, STREAM_URL, times: 1
    end

    def test_a_server_error_the_block_raises_itself_is_still_sent_again
      failure = ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
      attempts = 0
      client = Client.new

      internals(client).instance_variable_get(:@retry_handler).stub(:sleep, nil) do
        assert_equal 2, client.with_retries { ((attempts += 1) < 2) ? raise(failure) : attempts }
      end
    end

    def test_the_retry_handler_raises_at_once_for_an_error_a_callback_raised
      [ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable")),
        NetworkError.new("boom")].each do |failure|
        untag(failure)

        assert_equal 1, attempts_to_send(failure)
      end
    end

    def test_untagging_notes_the_error_a_callback_raised
      failure = ArgumentError.new("the callback failed")
      before = Core.const_get(:CallbackError).untagged?(failure)

      assert_same failure, untag(failure)
      assert_equal [false, true, false], [before, Core.const_get(:CallbackError).untagged?(failure),
        Core.const_get(:CallbackError).untagged?(ArgumentError.new("the callback failed"))]
    end

    def test_the_errors_untagged_are_named_privately
      assert_raises(NameError) { Core.const_get(:CallbackError)::UNTAGGED }
    end

    private

    # Run the block, failing the test if the client would wait to send a request again
    def without_retries(client, &)
      internals(client).instance_variable_get(:@retry_handler).stub(:sleep, ->(_) { flunk "sent again for a callback's error" }, &)
    end

    # The times the retry handler runs a block that raises the error, which it raises in the end
    def attempts_to_send(failure)
      attempts = 0
      assert_raises(failure.class) do
        Core.const_get(:RetryHandler).new.handle(idempotent: true, resend_unanswered: true) do
          attempts += 1
          raise failure
        end
      end
      attempts
    end

    # Note an error as one a callback raised, as a request does once it is left
    def untag(error) = Core.const_get(:CallbackError).untag(Core.const_get(:CallbackError).new(error))
  end
end
