require_relative "../test_helper"

module X
  # Request tests for X::Client class
  class ClientRequestTest < Minitest::Test
    cover Client

    def setup
      @client = Client.new
    end

    def test_get_request
      stub_request(:get, "https://api.twitter.com/2/tweets")
      @client.get("tweets")

      assert_requested :get, "https://api.twitter.com/2/tweets"
    end

    def test_get_request_with_headers
      headers = {"User-Agent" => "Custom User Agent"}
      stub_request(:get, "https://api.twitter.com/2/tweets")
      @client.get("tweets", headers: headers)

      assert_requested :get, "https://api.twitter.com/2/tweets", headers: headers
    end

    def test_post_request
      stub_request(:post, "https://api.twitter.com/2/tweets")
      @client.post("tweets")

      assert_requested :post, "https://api.twitter.com/2/tweets"
    end

    def test_post_request_with_headers
      headers = {"User-Agent" => "Custom User Agent"}
      stub_request(:post, "https://api.twitter.com/2/tweets")
      @client.post("tweets", headers: headers)

      assert_requested :post, "https://api.twitter.com/2/tweets", headers: headers
    end

    def test_put_request
      stub_request(:put, "https://api.twitter.com/2/tweets")
      @client.put("tweets")

      assert_requested :put, "https://api.twitter.com/2/tweets"
    end

    def test_put_request_with_headers
      headers = {"User-Agent" => "Custom User Agent"}
      stub_request(:put, "https://api.twitter.com/2/tweets")
      @client.put("tweets", headers: headers)

      assert_requested :put, "https://api.twitter.com/2/tweets", headers: headers
    end

    def test_delete_request
      stub_request(:delete, "https://api.twitter.com/2/tweets")
      @client.delete("tweets")

      assert_requested :delete, "https://api.twitter.com/2/tweets"
    end

    def test_delete_request_with_headers
      headers = {"User-Agent" => "Custom User Agent"}
      stub_request(:delete, "https://api.twitter.com/2/tweets")
      @client.delete("tweets", headers: headers)

      assert_requested :delete, "https://api.twitter.com/2/tweets", headers: headers
    end

    def test_redirect_handler_preserves_authentication
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, max_redirects: 5)
      stub_request(:get, "https://api.twitter.com/old_endpoint")
        .with(headers: {"Authorization" => /Bearer #{TEST_BEARER_TOKEN}/o})
        .to_return(status: 301, headers: {"Location" => "https://api.twitter.com/new_endpoint"})
      stub_request(:get, "https://api.twitter.com/new_endpoint")
        .with(headers: {"Authorization" => /Bearer #{TEST_BEARER_TOKEN}/o})
      client.get("/old_endpoint")

      assert_requested :get, "https://api.twitter.com/old_endpoint"
      assert_requested :get, "https://api.twitter.com/new_endpoint"
    end

    def test_follows_301_redirect
      stub_request(:get, "https://api.twitter.com/old_endpoint")
        .to_return(status: 301, headers: {"Location" => "https://api.twitter.com/new_endpoint"})
      stub_request(:get, "https://api.twitter.com/new_endpoint")
      @client.get("/old_endpoint")

      assert_requested :get, "https://api.twitter.com/new_endpoint"
    end

    def test_follows_302_redirect
      stub_request(:get, "https://api.twitter.com/old_endpoint")
        .to_return(status: 302, headers: {"Location" => "https://api.twitter.com/new_endpoint"})
      stub_request(:get, "https://api.twitter.com/new_endpoint")
      @client.get("/old_endpoint")

      assert_requested :get, "https://api.twitter.com/new_endpoint"
    end

    def test_follows_307_redirect
      stub_request(:post, "https://api.twitter.com/temporary_redirect")
        .to_return(status: 307, headers: {"Location" => "https://api.twitter.com/new_endpoint"})
      body = {key: "value"}.to_json
      stub_request(:post, "https://api.twitter.com/new_endpoint")
        .with(body: body)
      @client.post("/temporary_redirect", body)

      assert_requested :post, "https://api.twitter.com/new_endpoint", body: body
    end

    def test_follows_308_redirect
      stub_request(:put, "https://api.twitter.com/temporary_redirect")
        .to_return(status: 308, headers: {"Location" => "https://api.twitter.com/new_endpoint"})
      body = {key: "value"}.to_json
      stub_request(:put, "https://api.twitter.com/new_endpoint")
        .with(body: body)
      @client.put("/temporary_redirect", body)

      assert_requested :put, "https://api.twitter.com/new_endpoint", body: body
    end

    def test_avoids_infinite_redirect_loop
      stub_request(:get, "https://api.twitter.com/infinite_loop")
        .to_return(status: 302, headers: {"Location" => "https://api.twitter.com/infinite_loop"})

      assert_raises TooManyRedirects do
        @client.get("/infinite_loop")
      end
    end
  end
end
