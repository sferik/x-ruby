require_relative "../test_helper"

module X
  # Tests for X::ResponseHandler class
  class ResponseHandlerTest < Minitest::Test
    def setup
      @response_handler = ResponseHandler.new
      @client = Client.new(base_url: "https://upload.twitter.com/1.1/", **oauth_credentials)
    end

    def test_that_it_handles_204_no_content_response
      stub_request(:post, "https://upload.twitter.com/1.1/media/upload.json")
        .to_return(status: 204)

      response = @client.post("/1.1/media/upload.json")

      assert_nil(response)
    end
  end
end
