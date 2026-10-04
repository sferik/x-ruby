# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientOnResponseTest < Minitest::Test
    cover_client

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

    def redirect_to_a_missing_resource
      stub_request(:post, "https://api.x.com/2/old").to_return(status: 303, headers: {"Location" => "https://api.x.com/2/new"})
      stub_request(:get, "https://api.x.com/2/new").to_return(status: 404, body: '{"title":"Not Found"}', headers: {"Content-Type" => "application/json"})
      assert_raises(NotFound) { @client.post("old", {text: "hi"}) }
    end

    def test_a_redirected_request_is_reported_for_the_request_the_response_answers
      redirect_to_a_missing_resource

      assert_equal [[:get, "https://api.x.com/2/new", 404]], @responses.map { |response| [response.http_method, response.uri.to_s, response.status] }
    end

    def test_the_error_of_a_redirected_request_names_the_request_the_response_answers
      error = redirect_to_a_missing_resource

      assert_equal [:get, "https://api.x.com/2/new"], [error.http_method, error.uri.to_s]
      assert_match(%r{\AGET /2/new: }, error.message)
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
