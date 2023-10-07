require_relative "../test_helper"

module X
  # Tests for X::RedirectHandler class
  class RedirectHandlerTest < Minitest::Test
    def setup
      @client = client
    end

    def test_follows_301_redirect
      stub_request(:get, "https://api.twitter.com/old_endpoint")
        .to_return(status: 301, headers: {"Location" => "https://api.twitter.com/new_endpoint"})

      stub_request(:get, "https://api.twitter.com/new_endpoint")
        .to_return(status: 200, headers: {"content-type" => "application/json"}, body: '{"message":"success"}')

      response = @client.get("/old_endpoint")

      assert_equal("success", response["message"])
    end

    def test_follows_302_redirect
      stub_request(:get, "https://api.twitter.com/temp_redirect")
        .to_return(status: 302, headers: {"Location" => "https://api.twitter.com/new_endpoint"})

      stub_request(:get, "https://api.twitter.com/new_endpoint")
        .to_return(status: 200, headers: {"content-type" => "application/json"}, body: '{"message":"success"}')

      response = @client.get("/temp_redirect")

      assert_equal("success", response["message"])
    end

    def test_follows_307_preserving_method_and_body
      stub_request(:post, "https://api.twitter.com/temporary_redirect")
        .to_return(status: 307, headers: {"Location" => "https://api.twitter.com/new_endpoint"})

      stub_request(:post, "https://api.twitter.com/new_endpoint")
        .to_return(status: 200, headers: {"content-type" => "application/json"}, body: '{"message":"success"}')

      response = @client.post("/temporary_redirect", '{"key": "value"}')

      assert_equal("success", response["message"])
    end

    def test_follows_308_preserving_method_and_body
      stub_request(:post, "https://api.twitter.com/permanent_redirect")
        .to_return(status: 308, headers: {"Location" => "https://api.twitter.com/new_endpoint"})

      stub_request(:post, "https://api.twitter.com/new_endpoint")
        .to_return(status: 200, headers: {"content-type" => "application/json"}, body: '{"message":"success"}')

      response = @client.post("/permanent_redirect", '{"key": "value"}')

      assert_equal("success", response["message"])
    end

    def test_avoids_infinite_redirect_loop
      stub_request(:get, "https://api.twitter.com/infinite_loop")
        .to_return(status: 302, headers: {"Location" => "https://api.twitter.com/infinite_loop"})

      assert_raises TooManyRedirectsError do
        @client.get("/infinite_loop")
      end
    end
  end
end
