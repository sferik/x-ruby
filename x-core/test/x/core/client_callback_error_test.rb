# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An error a callback of a request raises is raised as it was, rather than taken for an error of the request,
  # which would send it again, wait out a rate limit, or refresh a token for it
  class ClientCallbackErrorTest < Minitest::Test
    cover_client
    cover Core::CallbackError
    cover Core::ResponseParser

    URL = "https://api.x.com/2/users/me"
    SUCCESS = {status: 200, body: '{"data":{"id":"1"}}', headers: {"Content-Type" => "application/json"}}.freeze

    # An object_class that builds its objects with a callable
    class Building
      def self.builder = @builder

      def self.with(builder) = Class.new(self) { @builder = builder }

      def self.from_response(body, client:) = builder.call(body, client)
    end

    def setup
      stub_request(:get, URL).to_return(SUCCESS)
    end

    def test_a_server_error_the_hook_raises_is_not_sent_again
      failure = ServiceUnavailable.new(http_response: Net::HTTPServiceUnavailable.new("1.1", "503", "Service Unavailable"))
      client = Client.new(on_response: ->(_) { raise failure })

      assert_same failure, assert_raises(ServiceUnavailable) { client.get("users/me") }
      assert_requested :get, URL, times: 1
    end

    def test_a_server_error_the_block_raises_is_not_sent_again
      failure = InternalServerError.new(http_response: Net::HTTPInternalServerError.new("1.1", "500", "Internal Server Error"))

      assert_same failure, assert_raises(InternalServerError) { Client.new.get("users/me") { |_| raise failure } }
      assert_requested :get, URL, times: 1
    end

    def test_a_server_error_from_response_raises_is_not_sent_again
      failure = BadGateway.new(http_response: Net::HTTPBadGateway.new("1.1", "502", "Bad Gateway"))
      object_class = Building.with(->(_, _) { raise failure })

      assert_same failure, assert_raises(BadGateway) { Client.new.get("users/me", object_class:) }
      assert_requested :get, URL, times: 1
    end

    def test_a_rate_limit_a_callback_raises_is_not_waited_out
      client = Client.new(max_rate_limit_retries: 1, on_response: ->(_) { raise TooManyRequests.new(http_response: Net::HTTPTooManyRequests.new("1.1", "429", "Too Many Requests")) })
      handler = client.instance_variable_get(:@rate_limit_handler)

      handler.stub(:sleep, ->(_) { flunk "waited out a rate limit the hook raised" }) do
        assert_raises(TooManyRequests) { client.get("users/me") }
      end
      assert_requested :get, URL, times: 1
    end

    def test_a_rejection_a_callback_raises_refreshes_no_token
      refresh = stub_request(:post, "https://api.x.com/2/oauth2/token")
      client = Client.new(**test_oauth2_credentials)

      rejection = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized").tap { |response| response.uri = URI("https://api.x.com/2/users/1") }
      nested = Unauthorized.new(http_response: rejection)

      assert_same nested, assert_raises(Unauthorized) { client.get("users/me") { |_| raise nested } }
      assert_not_requested refresh
      assert_requested :get, URL, times: 1
    end

    def test_an_error_of_the_response_is_still_sent_again
      stub_request(:get, URL).to_return({status: 503}, SUCCESS)
      client = Client.new(max_retries: 1)

      client.instance_variable_get(:@retry_handler).stub(:sleep, nil) do
        assert_equal({"data" => {"id" => "1"}}, client.get("users/me"))
      end
    end

    def test_what_from_response_builds_is_returned
      object_class = Building.with(->(body, client) { [body, client] })
      client = Client.new

      assert_equal [{"data" => {"id" => "1"}}, client], client.get("users/me", object_class:)
    end

    def test_a_document_that_is_not_json_still_raises_invalid_response
      stub_request(:get, URL).to_return(status: 200, body: "{")

      assert_raises(InvalidResponse) { Client.new.get("users/me", object_class: Building.with(->(_, _) { flunk "built what is not JSON" })) }
    end

    def test_an_error_tagged_twice_stands_in_for_the_error_a_callback_raised
      failure = ArgumentError.new("the callback failed")
      error = assert_raises(Core::CallbackError) { Core::CallbackError.tagging { Core::CallbackError.tagging { raise failure } } }

      assert_same failure, error.error
    end

    def test_tagging_returns_what_the_callback_returned
      assert_equal 1, Core::CallbackError.tagging { 1 }
    end
  end
end
