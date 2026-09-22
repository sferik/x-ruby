# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientResponseBlockTest < Minitest::Test
    cover_client

    URL = "https://api.x.com/2/users/me"

    def setup
      @client = Client.new
      @responses = []
    end

    def test_a_lookup_yields_the_summary_of_its_response
      stub_request(:get, URL).to_return(body: '{"data":{"id":"1"}}', headers: {"x-rate-limit-limit" => "75", "x-rate-limit-remaining" => "74", "x-rate-limit-reset" => "1"})
      body = @client.get("users/me") { |response| @responses << response }

      assert_equal({"data" => {"id" => "1"}}, body)
      assert_equal [[:get, URL, 200, 74]], @responses.map { |response| [response.http_method, response.uri.to_s, response.status, response.rate_limit.remaining] }
    end

    def test_the_verbs_that_send_a_body_and_the_one_that_deletes_yield_their_responses
      stub_request(:post, "https://api.x.com/2/tweets").to_return(body: "{}")
      stub_request(:put, "https://api.x.com/2/tweets/1").to_return(body: "{}")
      stub_request(:delete, "https://api.x.com/2/tweets/1").to_return(body: "{}")
      collect = ->(response) { @responses << response.http_method }
      @client.post("tweets", {text: "hi"}, &collect)
      @client.put("tweets/1", {text: "hi"}, &collect)
      @client.delete("tweets/1", &collect)

      assert_equal %i[post put delete], @responses
    end

    def test_the_block_receives_a_refused_response_before_the_error
      stub_request(:get, URL).to_return(status: 404, body: '{"title":"Not Found"}')

      assert_raises(NotFound) { @client.get("users/me") { |response| @responses << response.status } }
      assert_equal [404], @responses
    end

    def test_the_hook_of_the_client_and_the_block_of_the_request_share_one_summary
      stub_request(:get, URL).to_return(body: "{}")
      client = Client.new(on_response: ->(response) { @responses << [:hook, response] })
      client.get("users/me") { |response| @responses << [:block, response] }

      assert_equal %i[hook block], @responses.map(&:first)
      assert_same @responses.first.last, @responses.last.last
    end

    def test_a_request_the_api_failed_to_answer_yields_every_attempt
      stub_request(:get, URL).to_return({status: 503}, {status: 200, body: "{}"})
      client = Client.new(max_retries: 1)
      handler = client.instance_variable_get(:@retry_handler)
      handler.stub(:sleep, nil) { client.get("users/me") { |response| @responses << response.status } }

      assert_equal [503, 200], @responses
    end

    # A request with nothing to report to is the common one, so it summarizes no response at all
    def test_a_request_with_neither_a_block_nor_a_hook_summarizes_nothing
      stub_request(:get, URL).to_return(body: "{}")

      Response.stub(:new, ->(*) { flunk "summarized a response with nothing to pass it to" }) { @client.get("users/me") }
    end
  end
end
