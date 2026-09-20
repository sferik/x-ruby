# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientHeadersTest < Minitest::Test
    cover_client
    cover StreamingClient

    def test_a_client_sends_no_headers_of_its_own_by_default
      assert_empty Client.new.headers
    end

    def test_the_headers_are_sent_with_every_request
      client = Client.new(headers: {"X-Trace" => "abc"})
      stub_request(:get, "https://api.x.com/2/users/me")
      stub_request(:delete, "https://api.x.com/2/tweets/1")
      client.get("users/me")
      client.delete("tweets/1")

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"X-Trace" => "abc"}
      assert_requested :delete, "https://api.x.com/2/tweets/1", headers: {"X-Trace" => "abc"}
    end

    def test_the_headers_replace_a_default_of_the_gem
      stub_request(:get, "https://api.x.com/2/users/me")
      Client.new(headers: {"User-Agent" => "my-app/1.0"}).get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"User-Agent" => "my-app/1.0"}
    end

    def test_a_header_of_a_request_replaces_one_of_the_client
      stub_request(:get, "https://api.x.com/2/users/me")
      Client.new(headers: {"X-Trace" => "client"}).get("users/me", headers: {"X-Trace" => "request"})

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"X-Trace" => "request"}
    end

    def test_the_form_content_type_is_sent_in_place_of_one_of_the_clients_headers
      stub_request(:post, "https://api.x.com/2/settings")
      Client.new(headers: {"Content-Type" => "application/json; charset=utf-8"}).post("settings", form: {lang: "en"})

      assert_requested :post, "https://api.x.com/2/settings",
        headers: {"Content-Type" => "application/x-www-form-urlencoded; charset=utf-8"}
    end

    def test_the_headers_are_frozen_and_copied_from_the_hash_given
      given = {"X-Trace" => "abc"}
      client = Client.new(headers: given)
      given["X-Trace"] = "changed"

      assert_predicate client.headers, :frozen?
      assert_equal({"X-Trace" => "abc"}, client.headers)
    end

    def test_the_headers_can_be_replaced
      client = Client.new(headers: {"X-Trace" => "abc"})
      client.headers = {"X-Trace" => "xyz"}
      stub_request(:get, "https://api.x.com/2/users/me")
      client.get("users/me")

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"X-Trace" => "xyz"}
    end

    def test_a_copy_keeps_the_headers
      assert_equal({"X-Trace" => "abc"}, Client.new(headers: {"X-Trace" => "abc"}).copy(max_redirects: 1).headers)
    end

    def test_a_copy_can_replace_the_headers
      assert_equal({"X-Trace" => "xyz"}, Client.new(headers: {"X-Trace" => "abc"}).copy(headers: {"X-Trace" => "xyz"}).headers)
    end

    def test_a_stream_sends_the_headers_of_its_client
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"X-Trace" => "abc"})
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "")
      client.streaming(max_reconnects: 0).stream("tweets/search/stream") { |object| object }

      assert_requested :get, "https://api.x.com/2/tweets/search/stream", headers: {"X-Trace" => "abc"}
    end

    def test_a_header_of_a_stream_replaces_one_of_the_client
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"X-Trace" => "client"})
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "")
      client.streaming(max_reconnects: 0).stream("tweets/search/stream", headers: {"X-Trace" => "stream"}) { |object| object }

      assert_requested :get, "https://api.x.com/2/tweets/search/stream", headers: {"X-Trace" => "stream"}
    end

    def test_a_redirect_to_another_origin_drops_a_header_of_the_client_that_carries_credentials
      redirect_to("https://elsewhere.example.com/users/me", headers: {"Cookie" => "session=secret", "X-Trace" => "abc"})

      assert_equal ["abc", nil], headers_sent_to("elsewhere.example.com").values_at("X-Trace", "Cookie")
    end

    def test_a_redirect_to_the_same_origin_keeps_every_header_of_the_client
      redirect_to("https://api.x.com/2/next", headers: {"Cookie" => "session=secret", "X-Trace" => "abc"})

      assert_requested :get, "https://api.x.com/2/next", headers: {"Cookie" => "session=secret", "X-Trace" => "abc"}
    end

    private

    # Send a request that is redirected to url, from a client that sends headers with every request
    def redirect_to(url, headers:)
      stub_request(:get, "https://api.x.com/2/users/me").to_return(status: 302, headers: {"Location" => url})
      stub_request(:get, url)
      Client.new(headers:).get("users/me")
    end

    # The headers of the request that reached a host
    def headers_sent_to(host)
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys
        .find { |signature| signature.uri.host.eql?(host) }.headers.to_h
    end
  end
end
