require_relative "../test_helper"

module X
  # Tests for X::ResponseHandler class
  class ResponseHandlerTest < Minitest::Test
    cover Client
    def setup
      @client = client
    end

    def test_that_it_handles_204_no_content_response
      @client = Client.new(base_url: "https://upload.twitter.com/1.1/", **oauth_credentials)
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json")
        .to_return(status: 204)

      response = @client.post("/1.1/media/upload.json")

      assert_nil response
    end

    def test_that_it_sets_error_message_from_detail
      body = {title: "title", detail: "detail"}.to_json
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .to_return(status: 400, headers: {"content-type" => "application/json"}, body: body)

      begin
        @client.get("tweets")
      rescue BadRequest => e
        assert_equal "title: detail", e.message
      end
    end

    def test_that_it_sets_error_message_from_errors_array
      body = {errors: [{message: "message 1"}, {message: "message 2"}]}.to_json
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .to_return(status: 400, headers: {"content-type" => "application/json"}, body: body)

      begin
        @client.get("tweets")
      rescue BadRequest => e
        assert_equal "message 1, message 2", e.message
      end
    end

    def test_that_it_sets_error_message_from_error
      body = {error: "error"}.to_json
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .to_return(status: 400, headers: {"content-type" => "application/json"}, body: body)

      begin
        @client.get("tweets")
      rescue BadRequest => e
        assert_equal "error", e.message
      end
    end

    def test_that_it_sets_error_message_from_message
      stub_request(:get, "https://api.twitter.com/2/tweets")
        .to_return(status: [400, "Bad Request"], headers: {"content-type" => "application/json"}, body: {}.to_json)

      begin
        @client.get("tweets")
      rescue BadRequest => e
        assert_equal "Bad Request", e.message
      end
    end
  end
end
