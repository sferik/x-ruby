require "json"
require_relative "../../test_helper"

module X
  class ClientBodyTest < Minitest::Test
    cover Client

    def setup
      @client = Client.new
    end

    def test_post_encodes_a_hash_body_as_json
      stub_request(:post, "https://api.twitter.com/2/tweets")
      @client.post("tweets", {text: "Hello"})

      assert_requested :post, "https://api.twitter.com/2/tweets", body: '{"text":"Hello"}',
        headers: {"Content-Type" => "application/json; charset=utf-8"}
    end

    def test_put_encodes_a_hash_body_as_json
      stub_request(:put, "https://api.twitter.com/2/tweets/1")
      @client.put("tweets/1", {"text" => "Hello"})

      assert_requested :put, "https://api.twitter.com/2/tweets/1", body: '{"text":"Hello"}'
    end

    def test_post_encodes_a_hash_subclass_body_as_json
      stub_request(:post, "https://api.twitter.com/2/tweets")
      @client.post("tweets", Class.new(Hash).new.merge!(text: "Hello"))

      assert_requested :post, "https://api.twitter.com/2/tweets", body: '{"text":"Hello"}'
    end

    def test_post_sends_a_string_body_as_given
      stub_request(:post, "https://api.twitter.com/2/tweets")
      @client.post("tweets", '{"text": "Hello"}')

      assert_requested :post, "https://api.twitter.com/2/tweets", body: '{"text": "Hello"}'
    end

    def test_post_without_a_body
      stub_request(:post, "https://api.twitter.com/2/tweets")
      @client.post("tweets")

      assert_requested(:post, "https://api.twitter.com/2/tweets") { |request| request.body.to_s.empty? }
    end

    def test_post_encodes_a_form
      stub_request(:post, "https://api.twitter.com/1.1/account/settings.json")
      @client.post("/1.1/account/settings.json", form: {lang: "en", tile: true})

      assert_requested :post, "https://api.twitter.com/1.1/account/settings.json", body: "lang=en&tile=true",
        headers: {"Content-Type" => Client::FORM_CONTENT_TYPE}
    end

    def test_form_takes_precedence_over_the_body
      stub_request(:put, "https://api.twitter.com/2/settings")
      @client.put("settings", {ignored: true}, form: {lang: "en"})

      assert_requested :put, "https://api.twitter.com/2/settings", body: "lang=en"
    end

    def test_form_headers_can_be_overridden
      stub_request(:post, "https://api.twitter.com/2/settings")
      @client.post("settings", form: {lang: "en"}, headers: {"Content-Type" => "text/plain"})

      assert_requested :post, "https://api.twitter.com/2/settings", headers: {"Content-Type" => "text/plain"}
    end

    def test_form_headers_survive_redirects
      stub_request(:post, "https://api.twitter.com/2/old")
        .to_return(status: 307, headers: {"Location" => "https://api.twitter.com/2/new"})
      stub_request(:post, "https://api.twitter.com/2/new")
      @client.post("old", form: {lang: "en"})

      assert_requested :post, "https://api.twitter.com/2/new", body: "lang=en", headers: {"Content-Type" => Client::FORM_CONTENT_TYPE}
    end

    def test_form_body_is_signed
      client = Client.new(**test_oauth_credentials)
      stub_request(:post, "https://api.twitter.com/2/settings")
      client.post("settings", form: {lang: "en"})

      assert_requested(:post, "https://api.twitter.com/2/settings") { |request| request.headers["Authorization"].include?("oauth_signature") }
    end
  end
end
