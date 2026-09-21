# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientOnResponseTest < Minitest::Test
    cover_client
    cover StreamingClient

    def setup
      @responses = []
      @client = Client.new(on_response: ->(response) { @responses << response })
    end

    def test_on_response_receives_every_response
      stub_request(:get, "https://api.x.com/2/users/me").to_return(body: {data: {id: "1"}}.to_json, headers: {"x-rate-limit-remaining" => "74", "x-rate-limit-limit" => "75", "x-rate-limit-reset" => "1"})
      @client.get("users/me")

      assert_equal [[:get, "https://api.x.com/2/users/me", 200, 1]], @responses.map { |response| [response.http_method, response.uri.to_s, response.status, response.resource_count] }
      assert_equal 74, @responses.first.rate_limit.remaining
    end

    def test_on_response_receives_a_failed_response_before_the_error
      stub_request(:post, "https://api.x.com/2/tweets").to_return(status: 429, headers: {"x-rate-limit-remaining" => "0"})

      assert_raises(TooManyRequests) { @client.post("tweets", {text: "hi"}) }
      assert_equal [[:post, 429]], @responses.map { |response| [response.http_method, response.status] }
    end

    def test_on_response_receives_each_object_a_stream_delivers_before_it_is_yielded
      stub_request(:get, "https://api.x.com/2/tweets/sample/stream")
        .to_return(body: "{\"data\":{\"id\":\"1\"},\"includes\":{\"users\":[{\"id\":\"2\"}]}}\r\n\r\n{\"data\":{\"id\":\"3\"}}\r\n", headers: {"x-rate-limit-limit" => "50", "x-rate-limit-remaining" => "49", "x-rate-limit-reset" => "1"})
      events = []
      client = Client.new(on_response: ->(response) { events << [response.resource_count, response.rate_limit.remaining, response.uri.path] })
      client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |post| events << post.dig("data", "id") }

      assert_equal [[2, 49, "/2/tweets/sample/stream"], "1", [1, 49, "/2/tweets/sample/stream"], "3"], events
    end

    def test_on_response_receives_a_failed_stream_before_the_error
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(status: 429, body: '{"title":"Too Many Requests"}', headers: {"Content-Type" => "application/json"})

      assert_raises(TooManyRequests) { @client.streaming(max_reconnects: 0).stream("tweets/search/stream") { flunk "unexpected yield" } }
      assert_equal [[:get, 429, '{"title":"Too Many Requests"}']], @responses.map { |response| [response.http_method, response.status, response.body] }
    end

    def test_on_response_is_optional_and_a_copy_can_add_one
      stub_request(:delete, "https://api.x.com/2/tweets/1")
      client = Client.new
      client.delete("tweets/1")

      assert_nil client.on_response
      client.with(on_response: ->(response) { @responses << response }).delete("tweets/1")

      assert_equal [:delete], @responses.map(&:http_method)
    end

    def test_a_copy_keeps_on_response
      assert_same @client.on_response, @client.with(base_url: "https://api.x.com/1.1/").on_response
    end
  end
end
