# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # An authenticator of your own, a subclass of X::Authenticator that overrides headers, authenticates the requests of
  # a client given it, as the authenticators of x-core do
  class CustomAuthenticatorTest < Minitest::Test
    cover_client
    cover Core.const_get(:CredentialValidator)
    cover Authenticator

    # Signs each request with its method and path, as a scheme of an application's own might
    class SigningAuthenticator < Authenticator
      attr_reader :signed

      def initialize
        super
        @signed = []
      end

      def headers(request)
        @signed << [request.http_method, request.uri.to_s, request.body]
        {AUTHENTICATION_HEADER => "Signed #{request.http_method} #{request.uri.path}", "X-Signature" => "sig"}
      end
    end

    def setup
      @authenticator = SigningAuthenticator.new
      @client = Client.new(authenticator: @authenticator)
    end

    def test_a_client_sends_the_headers_its_authenticator_builds_for_each_request
      stub_request(:post, "https://api.x.com/2/tweets").with(headers: {"Authorization" => "Signed post /2/tweets", "X-Signature" => "sig"})
      @client.post("tweets", {text: "Hi"})

      assert_same @authenticator, @client.authenticator
      assert_equal [[:post, "https://api.x.com/2/tweets", '{"text":"Hi"}']], @authenticator.signed
    end

    def test_the_headers_of_the_authenticator_replace_headers_of_the_same_name
      stub_request(:get, "https://api.x.com/2/users/me").with(headers: {"Authorization" => "Signed get /2/users/me"})
      @client.get("users/me", headers: {"Authorization" => "Bearer SOMETHING_ELSE"})

      assert_requested :get, "https://api.x.com/2/users/me", headers: {"Authorization" => "Signed get /2/users/me"}
    end

    def test_a_request_to_another_origin_is_not_passed_to_the_authenticator
      stub_request(:get, "https://upload.x.com/1.1/media/upload.json")
      @client.get("https://upload.x.com/1.1/media/upload.json")

      assert_empty @authenticator.signed
      assert_requested(:get, "https://upload.x.com/1.1/media/upload.json") { |request| !request.headers.key?("Authorization") }
    end

    def test_a_copy_and_the_app_only_client_authenticate_with_it
      assert_same @client, @client.app_only
      assert_same @authenticator, @client.with(max_retries: 0).authenticator
    end

    def test_a_stream_is_opened_with_it
      stub_request(:get, "https://api.x.com/2/tweets/sample/stream").with(headers: {"Authorization" => "Signed get /2/tweets/sample/stream"})
        .to_return(body: "{\"data\":{\"id\":\"1\"}}\r\n")
      streamed = []
      until_the_stream_ends { @client.streaming(max_reconnects: 0).stream("tweets/sample/stream") { |object| streamed << object } }

      assert_equal [{"data" => {"id" => "1"}}], streamed
    end
  end
end
