# frozen_string_literal: true

require_relative "../../test_helper"

module X
  class ClientOriginTest < Minitest::Test
    include StreamHelpers

    cover_client
    cover Core::Origin

    AUTHORIZATION = "Bearer #{TEST_BEARER_TOKEN}".freeze

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def authorization_sent_to(url)
      WebMock::RequestRegistry.instance.requested_signatures.hash.keys
        .find { |signature| signature.uri.to_s.eql?(url) }&.headers.to_h["Authorization"]
    end

    def test_an_endpoint_of_the_base_url_carries_the_credentials
      stub_request(:get, "https://api.x.com/2/users/me")
      @client.get("users/me")

      assert_equal AUTHORIZATION, authorization_sent_to("https://api.x.com:443/2/users/me")
    end

    def test_a_whole_url_of_the_same_origin_carries_the_credentials
      stub_request(:get, "https://api.x.com/1.1/account/settings.json")
      @client.get("https://API.x.com/1.1/account/settings.json")

      assert_equal AUTHORIZATION, authorization_sent_to("https://api.x.com:443/1.1/account/settings.json")
    end

    def test_a_whole_url_of_another_host_carries_none
      stub_request(:get, "https://example.com/steal")
      @client.get("https://example.com/steal")

      assert_nil authorization_sent_to("https://example.com:443/steal")
    end

    def test_a_whole_url_of_another_scheme_carries_none
      stub_request(:get, "http://api.x.com/2/users/me")
      @client.get("http://api.x.com/2/users/me")

      assert_nil authorization_sent_to("http://api.x.com:80/2/users/me")
    end

    def test_a_whole_url_of_another_port_carries_none
      stub_request(:get, "https://api.x.com:8443/2/users/me")
      @client.get("https://api.x.com:8443/2/users/me")

      assert_nil authorization_sent_to("https://api.x.com:8443/2/users/me")
    end

    def test_a_request_to_another_origin_drops_every_header_that_carries_credentials
      stub_request(:get, "https://example.com/steal")
      @client.get("https://example.com/steal", headers: {"cookie" => "session=secret", "Authorization" => "Basic secret",
                                                         "Proxy-Authorization" => "Basic proxy", "X-Custom" => "kept"})

      assert_requested(:get, "https://example.com/steal", headers: {"X-Custom" => "kept"}) do |request|
        request.headers.to_h.values_at("Authorization", "Cookie", "Proxy-Authorization").eql?([nil, nil, nil])
      end
    end

    def test_a_request_to_another_origin_drops_the_headers_of_the_client_that_carry_credentials
      client = Client.new(bearer_token: TEST_BEARER_TOKEN, headers: {"Cookie" => "session=secret", "X-Custom" => "kept"})
      stub_request(:get, "https://example.com/steal")
      client.get("https://example.com/steal")

      assert_requested(:get, "https://example.com/steal", headers: {"X-Custom" => "kept"}) do |request|
        request.headers.to_h["Cookie"].nil?
      end
    end

    def test_a_request_of_a_client_of_another_base_url_carries_the_credentials_there
      client = @client.with(base_url: "https://example.com/v1/")
      stub_request(:get, "https://example.com/v1/users/me")
      client.get("users/me")

      assert_equal AUTHORIZATION, authorization_sent_to("https://example.com:443/v1/users/me")
    end

    def test_a_stream_of_the_base_url_carries_the_credentials
      stub_request(:get, "https://api.x.com/2/tweets/search/stream").to_return(body: "")
      stream_and_collect("tweets/search/stream")

      assert_equal AUTHORIZATION, authorization_sent_to("https://api.x.com:443/2/tweets/search/stream")
    end

    def test_a_stream_of_another_origin_carries_none
      stub_request(:get, "https://example.com/stream").to_return(body: "")
      stream_and_collect("https://example.com/stream")

      assert_nil authorization_sent_to("https://example.com:443/stream")
    end
  end
end
