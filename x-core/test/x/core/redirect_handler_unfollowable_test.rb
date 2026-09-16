require_relative "../../test_helper"

module X
  class RedirectHandlerUnfollowableTest < Minitest::Test
    cover RedirectHandler

    def setup
      @redirect_handler = RedirectHandler.new
      @request = Net::HTTP::Get.new(URI("https://api.x.com/2/users/me"))
    end

    def found(location)
      Net::HTTPFound.new("1.1", "302", "Found").tap { |response| response["Location"] = location unless location.nil? }
    end

    def test_a_response_that_is_not_a_redirect_is_returned_whatever_its_location
      response = Net::HTTPCreated.new("1.1", "201", "Created").tap { |created| created["Location"] = "https://example.com/created" }

      assert_same response, @redirect_handler.handle(response:, request: @request, redirect_count: RedirectHandler::DEFAULT_MAX_REDIRECTS)
      assert_not_requested :get, "https://example.com/created"
    end

    def test_a_redirect_without_a_location_is_returned
      response = found(nil)

      assert_same response, @redirect_handler.handle(response:, request: @request)
    end

    def test_not_modified_is_returned
      response = Net::HTTPNotModified.new("1.1", "304", "Not Modified")

      assert_same response, @redirect_handler.handle(response:, request: @request)
    end

    def test_a_redirect_to_a_url_that_is_not_http_is_returned
      response = found("ftp://example.com/file")

      assert_same response, @redirect_handler.handle(response:, request: @request)
    end

    def test_a_redirect_to_an_invalid_url_is_returned
      response = found("ht tp://example.com")

      assert_same response, @redirect_handler.handle(response:, request: @request)
    end

    def test_a_redirect_to_an_https_url_is_followed
      stub_request(:get, "https://example.com/next")
      response = @redirect_handler.handle(response: found("https://example.com/next"), request: @request)

      assert_equal "200", response.code
    end

    def test_the_client_raises_an_http_error_for_a_redirect_it_cannot_follow
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 302, body: "")
      client = Client.new(bearer_token: TEST_BEARER_TOKEN)

      error = assert_raises(HTTPError) { client.get("users/me") }
      assert_equal 302, error.status
    end
  end
end
