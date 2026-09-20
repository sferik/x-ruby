require "json"
require_relative "../../test_helper"

module X
  class ClientBodyTest < Minitest::Test
    cover Client

    def setup
      @client = Client.new
    end

    def test_post_encodes_a_hash_body_as_json
      stub_request(:post, "https://api.x.com/2/tweets")
      @client.post("tweets", {text: "Hello"})

      assert_requested :post, "https://api.x.com/2/tweets", body: '{"text":"Hello"}',
        headers: {"Content-Type" => "application/json; charset=utf-8"}
    end

    def test_put_encodes_a_hash_body_as_json
      stub_request(:put, "https://api.x.com/2/tweets/1")
      @client.put("tweets/1", {"text" => "Hello"})

      assert_requested :put, "https://api.x.com/2/tweets/1", body: '{"text":"Hello"}'
    end

    def test_post_encodes_a_hash_subclass_body_as_json
      stub_request(:post, "https://api.x.com/2/tweets")
      @client.post("tweets", Class.new(Hash).new.merge!(text: "Hello"))

      assert_requested :post, "https://api.x.com/2/tweets", body: '{"text":"Hello"}'
    end

    def test_post_sends_a_string_body_as_given
      stub_request(:post, "https://api.x.com/2/tweets")
      @client.post("tweets", '{"text": "Hello"}')

      assert_requested :post, "https://api.x.com/2/tweets", body: '{"text": "Hello"}'
    end

    def test_post_without_a_body
      stub_request(:post, "https://api.x.com/2/tweets")
      @client.post("tweets")

      assert_requested(:post, "https://api.x.com/2/tweets") { |request| request.body.to_s.empty? }
    end

    def test_post_encodes_a_form
      stub_request(:post, "https://api.x.com/1.1/account/settings.json")
      @client.post("https://api.x.com/1.1/account/settings.json", form: {lang: "en", tile: true})

      assert_requested :post, "https://api.x.com/1.1/account/settings.json", body: "lang=en&tile=true",
        headers: {"Content-Type" => "application/x-www-form-urlencoded; charset=utf-8"}
    end

    def test_a_body_beside_a_form_is_refused_before_any_request
      error = assert_raises(ArgumentError) { @client.put("settings", {dropped: true}, form: {lang: "en"}) }

      assert_equal "Pass a body or form fields, not both, since a request sends one body", error.message
      assert_not_requested :put, "https://api.x.com/2/settings"
    end

    def test_post_encodes_an_array_body_as_json
      stub_request(:post, "https://api.x.com/2/tweets")
      @client.post("tweets", [{text: "Hello"}, {text: "World"}])

      assert_requested :post, "https://api.x.com/2/tweets", body: '[{"text":"Hello"},{"text":"World"}]',
        headers: {"Content-Type" => "application/json; charset=utf-8"}
    end

    def test_post_sends_a_string_subclass_body_as_given
      stub_request(:post, "https://api.x.com/2/tweets")
      @client.post("tweets", Class.new(String).new('{"text": "Hello"}'))

      assert_requested :post, "https://api.x.com/2/tweets", body: '{"text": "Hello"}'
    end

    def test_form_headers_can_be_overridden
      stub_request(:post, "https://api.x.com/2/settings")
      @client.post("settings", form: {lang: "en"}, headers: {"Content-Type" => "text/plain"})

      assert_requested :post, "https://api.x.com/2/settings", headers: {"Content-Type" => "text/plain"}
    end

    def test_form_headers_survive_redirects
      stub_request(:post, "https://api.x.com/2/old")
        .to_return(status: 307, headers: {"Location" => "https://api.x.com/2/new"})
      stub_request(:post, "https://api.x.com/2/new")
      @client.post("old", form: {lang: "en"})

      assert_requested :post, "https://api.x.com/2/new", body: "lang=en", headers: {"Content-Type" => "application/x-www-form-urlencoded; charset=utf-8"}
    end

    def test_form_body_is_signed
      client = Client.new(**test_oauth_credentials)
      stub_request(:post, "https://api.x.com/2/settings")
      client.post("settings", form: {lang: "en"})

      assert_requested(:post, "https://api.x.com/2/settings") { |request| request.headers["Authorization"].include?("oauth_signature") }
    end
  end
end
