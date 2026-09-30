# frozen_string_literal: true

require_relative "../../test_helper"

module X
  # The fields of a body given without the braces of a Hash are refused with how to pass them
  class ClientBodyKeywordsTest < Minitest::Test
    cover Client
    cover Core::SettingValidator

    def setup
      @client = Client.new(bearer_token: TEST_BEARER_TOKEN)
    end

    def test_post_refuses_the_fields_of_a_body_given_without_braces_before_a_request
      error = assert_raises(ArgumentError) { @client.post("tweets", text: "Hello") }

      assert_equal 'unknown keyword: :text; pass a body as a Hash in braces, as post("tweets", {text: "Hello"})', error.message
      assert_not_requested :post, "https://api.x.com/2/tweets"
    end

    def test_put_names_each_keyword_it_takes_none_of
      error = assert_raises(ArgumentError) { @client.put("lists/1", name: "Rubyists", private: true) }

      assert_equal 'unknown keywords: :name, :private; pass a body as a Hash in braces, as put("lists/1", {name: "Rubyists", private: true})',
        error.message
    end

    def test_a_body_in_braces_is_sent
      stub_request(:post, "https://api.x.com/2/tweets").to_return(headers: {"Content-Type" => "application/json"}, body: "{}")
      @client.post("tweets", {text: "Hello"})

      assert_requested :post, "https://api.x.com/2/tweets", body: {text: "Hello"}.to_json
    end
  end
end
